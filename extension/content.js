"use strict";

(() => {
  const pageUrl = new URL(window.location.href);
  const runId = pageUrl.searchParams.get("lbk_v3_run");
  const probe = pageUrl.searchParams.get("lbk_v3_probe") === "1";
  const mode = pageUrl.searchParams.get("lbk_v3_mode");
  if (!runId || (!probe && !mode)) return;

  const API_LIST = (page) => `https://www.lidl.hu/mre/api/v1/tickets?country=HU&page=${page}`;
  const API_DETAIL = (id) => `https://www.lidl.hu/mre/api/v1/tickets/${encodeURIComponent(id)}?country=HU&languageCode=hu-HU`;
  const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  function badge(text, isError = false) {
    let el = document.getElementById("lbk-v3-status");
    if (!el) {
      el = document.createElement("div");
      el.id = "lbk-v3-status";
      Object.assign(el.style, {
        position: "fixed",
        right: "16px",
        bottom: "16px",
        zIndex: "2147483647",
        padding: "10px 14px",
        borderRadius: "8px",
        fontFamily: "sans-serif",
        fontSize: "14px",
        boxShadow: "0 2px 12px rgba(0,0,0,.35)",
        maxWidth: "420px"
      });
      document.documentElement.appendChild(el);
    }
    el.textContent = text;
    el.style.background = isError ? "#8b1e1e" : "#123d73";
    el.style.color = "white";
  }

  async function native(payload) {
    const response = await browser.runtime.sendMessage({
      source: "lidl-blokkkereso-v3-content",
      payload
    });
    if (!response || !response.ok) {
      throw new Error(response && response.error ? response.error : "Native Messaging hiba");
    }
    if (!response.native || !response.native.ok) {
      throw new Error(response.native && response.native.error ? response.native.error : "Native host hiba");
    }
    return response.native;
  }

  async function fetchJson(url) {
    const response = await fetch(url, {
      method: "GET",
      credentials: "include",
      cache: "no-store",
      headers: { "Accept": "application/json" }
    });
    const text = await response.text();
    let data = null;
    try { data = JSON.parse(text); } catch (_) {}
    return { status: response.status, ok: response.ok, data, textLength: text.length };
  }

  async function reportFatal(message) {
    badge(`Lidl blokkkereső v3: HIBA – ${message}`, true);
    try {
      await native({
        action: "sync_error",
        runId,
        message: String(message),
        at: new Date().toISOString()
      });
    } catch (_) {}
  }

  async function runProbe() {
    badge("Lidl blokkkereső v3: munkamenet ellenőrzése…");
    const result = await fetchJson(API_LIST(1));
    const data = result.data && typeof result.data === "object" ? result.data : {};
    await native({
      action: "probe_result",
      runId,
      httpStatus: result.status,
      ok: result.ok && Array.isArray(data.items),
      page: data.page ?? null,
      size: data.size ?? null,
      totalCount: data.totalCount ?? null,
      itemsCount: Array.isArray(data.items) ? data.items.length : null,
      at: new Date().toISOString()
    });
    badge(result.status === 200 ? "Lidl blokkkereső v3: munkamenet OK" : `Lidl blokkkereső v3: HTTP ${result.status}`, result.status !== 200);
  }

  async function runSync() {
    badge(`Lidl blokkkereső v3: ${mode === "full" ? "teljes" : "inkrementális"} szinkron…`);
    let page = 1;
    let totalPages = 1;
    let totalCount = 0;
    let lastPageFetched = 0;

    while (true) {
      const result = await fetchJson(API_LIST(page));
      if (!result.ok || !result.data || !Array.isArray(result.data.items)) {
        throw new Error(`A(z) ${page}. blokklista oldal HTTP ${result.status}`);
      }
      const pageSize = Number(result.data.size || 10);
      totalCount = Number(result.data.totalCount || result.data.items.length);
      totalPages = Math.max(1, Math.ceil(totalCount / Math.max(1, pageSize)));
      lastPageFetched = page;
      badge(`Lidl blokkkereső v3: lista ${page}/${totalPages}…`);

      const ack = await native({
        action: "list_page",
        runId,
        mode,
        page,
        pageSize,
        totalPages,
        totalCount,
        items: result.data.items,
        at: new Date().toISOString()
      });

      if (!ack.continueList) break;
      page += 1;
      await delay(250);
    }

    const reachedLastPage = lastPageFetched >= totalPages;
    const listDone = await native({
      action: "list_done",
      runId,
      mode,
      lastPageFetched,
      totalPages,
      totalCount,
      reachedLastPage,
      at: new Date().toISOString()
    });

    const pending = Array.isArray(listDone.pending) ? listDone.pending : [];
    let failures = 0;
    badge(`Lidl blokkkereső v3: feldolgozandó blokk: ${pending.length}`);

    for (let i = 0; i < pending.length; i += 1) {
      const ticket = pending[i];
      const id = String(ticket.id || "");
      if (!id) continue;
      const result = await fetchJson(API_DETAIL(id));
      let error = null;
      if (!result.ok || !result.data || typeof result.data !== "object") {
        failures += 1;
        error = `HTTP ${result.status}`;
      }
      await native({
        action: "detail_result",
        runId,
        receiptId: id,
        ticket,
        httpStatus: result.status,
        ok: !error,
        detail: !error ? result.data : null,
        error,
        detailIndex: i + 1,
        detailTotal: pending.length,
        at: new Date().toISOString()
      });
      badge(`Lidl blokkkereső v3: blokk ${i + 1}/${pending.length} · hibás: ${failures}`);
      await delay(350);
    }

    await native({
      action: "sync_done",
      runId,
      mode,
      totalCount,
      totalPages,
      reachedLastPage,
      pendingCount: pending.length,
      failures,
      at: new Date().toISOString()
    });
    badge(`Lidl blokkkereső v3: kész · ${pending.length} blokk · hibás: ${failures}`);
  }

  (async () => {
    try {
      if (probe) await runProbe();
      else await runSync();
    } catch (error) {
      console.error("[lidl-blokkkereso-v3]", error);
      await reportFatal(error instanceof Error ? error.message : String(error));
    }
  })();
})();
