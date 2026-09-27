#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -Eeuo pipefail

# V3.0.0: a Lidl API-hívásokat a felhasználó valódi Firefoxa végzi WebExtensionből.
# Az adatok Firefox Native Messaginggel kerülnek vissza a helyi SQLite indexbe.

APP_ID="lidl-blokkkereso"
APP_NAME="Lidl blokk- és termékkereső"
APP_VERSION="3.0.1"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_ID}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_ID}"
PY_APP="$CACHE_DIR/lidl_app.py"
INSTALL_PATH="$HOME/.local/bin/lidl-blokkkereso-v3"
DESKTOP_FILE="$HOME/.local/share/applications/lidl-blokkkereso-v3.desktop"

mkdir -p "$DATA_DIR" "$CACHE_DIR"

err() {
  printf '\nHIBA: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

install_desktop() {
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  cp -- "$0" "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Nem hivatalos helyi kereső a Lidl digitális nyugtáihoz
Exec=$INSTALL_PATH
Icon=utilities-terminal
Terminal=true
Categories=Utility;Office;
StartupNotify=true
EOF
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
  info "Telepítve: $INSTALL_PATH"
  info "Az alkalmazásmenüben keresd: $APP_NAME"
  exit 0
}

uninstall_desktop() {
  rm -f -- "$INSTALL_PATH" "$DESKTOP_FILE"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
  info "Az indító eltávolítva. A helyi adatbázis megmaradt itt: $DATA_DIR"
  exit 0
}

case "${1:-}" in
  --install) install_desktop ;;
  --uninstall) uninstall_desktop ;;
  --version)
    printf '%s %s\n' "$APP_NAME" "$APP_VERSION"
    exit 0
    ;;
  --about)
    cat <<'EOF'
Lidl blokk- és termékkereső – nem hivatalos közösségi eszköz.
Nem áll kapcsolatban a Lidl-lel, és a Lidl nem támogatja vagy hagyta jóvá.
A Lidl API-hívásokat a felhasználó normál Firefoxában futó WebExtension végzi.
A böngésző és a helyi alkalmazás Firefox Native Messaginggel kommunikál.
Nem tárol Lidl-jelszót, és nem másolja ki a Firefox cookie-adatbázisát.
A helyi blokkindex a felhasználó saját profiljában marad.
Licenc: MIT
EOF
    exit 0
    ;;
  --license)
    cat <<'EOF'
MIT License

Copyright (c) 2026 Lidl blokk- és termékkereső contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    exit 0
    ;;
esac

command -v python3 >/dev/null 2>&1 || err "A python3 nincs telepítve. Ubuntu/Debian: sudo apt install python3"

# A Python-rész mindig újraírásra kerül, így a .sh frissítése automatikusan frissíti az alkalmazást is.
awk '/^__LIDL_PYTHON_APP_BEGIN__$/ {found=1; next} /^__LIDL_PYTHON_APP_END__$/ {found=0} found {print}' "$0" > "$PY_APP"
chmod 600 "$PY_APP"

# Szándékosan lecseréljük a shell folyamatot a Python alkalmazásra.
# shellcheck disable=SC2093
exec python3 "$PY_APP" "$@"

# A következő heredoc az awk által kinyert beágyazott Python alkalmazás.
# Shell szempontból szándékosan nem végrehajtható.
# shellcheck disable=SC2317
: <<'__LIDL_PYTHON_PAYLOAD__'
__LIDL_PYTHON_APP_BEGIN__
from __future__ import annotations

import argparse
import curses
import datetime as dt
import html
import json
import locale
import os
import re
import secrets
import shutil
import subprocess
import sqlite3
import sys
import textwrap
import time
import unicodedata
import webbrowser
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable


APP_NAME = "Lidl blokk- és termékkereső"
APP_VERSION = "3.0.1"
BASE_URL = "https://www.lidl.hu"
LOGIN_URL = (
    BASE_URL
    + "/mla/?country_code=hu&language=hu-HU&client_id=HungaryRetailClient"
)
HOME_URL = (
    BASE_URL
    + "/mre/purchase-history?client_id=HungaryRetailClient"
      "&country_code=hu&language=hu-HU&page=1"
)
API_LIST = BASE_URL + "/mre/api/v1/tickets?country=HU&page={page}"
API_DETAIL = BASE_URL + "/mre/api/v1/tickets/{receipt_id}?country=HU&languageCode=hu-HU"
DETAIL_URL = BASE_URL + "/mre/purchase-detail?t={receipt_id}"

DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "lidl-blokkkereso"
DB_PATH = DATA_DIR / "lidl_receipts.sqlite3"
V3_RUNS_DIR = DATA_DIR / "v3-runs"
V3_HOST_NAME = "hu.lidl.blokkkereso"
V3_EXTENSION_ID = "lidl-blokkkereso-v3@rambo-junior"
V3_HOST_MANIFEST = Path.home() / ".mozilla/native-messaging-hosts" / f"{V3_HOST_NAME}.json"
V3_HOST_HELPER = Path.home() / ".local/lib/lidl-blokkkereso-v3/lidl-native-host.py"
V3_SYNC_TIMEOUT_SECONDS = int(os.environ.get("LIDL_V3_SYNC_TIMEOUT", "600"))
V3_PROBE_TIMEOUT_SECONDS = int(os.environ.get("LIDL_V3_PROBE_TIMEOUT", "30"))
V3_KEEP_RUNS = os.environ.get("LIDL_V3_KEEP_RUNS", "0") == "1"

DATA_DIR.mkdir(parents=True, exist_ok=True)
V3_RUNS_DIR.mkdir(parents=True, exist_ok=True)

try:
    locale.setlocale(locale.LC_ALL, "")
except locale.Error:
    pass



def normalize(value: Any) -> str:
    text = str(value or "")
    decomposed = unicodedata.normalize("NFD", text)
    return "".join(ch for ch in decomposed if unicodedata.category(ch) != "Mn").lower().strip()


def parse_number(value: Any) -> float | None:
    if value is None or value == "":
        return None
    cleaned = str(value).replace("\xa0", "").replace(" ", "").replace(",", ".")
    cleaned = re.sub(r"[^0-9.\-]", "", cleaned)
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def money(value: Any) -> str:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "–"
    if number.is_integer():
        return f"{int(number):,}".replace(",", " ") + " Ft"
    return f"{number:,.2f}".replace(",", "X").replace(".", ",").replace("X", " ") + " Ft"


def pretty_date(value: str | None) -> str:
    if not value:
        return "–"
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed.astimezone().strftime("%Y.%m.%d. %H:%M")
    except ValueError:
        return value


class ArticleParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.current: dict[str, str] | None = None
        self.current_text: list[str] = []
        self.articles: list[tuple[int, dict[str, str], str]] = []
        self.line_no = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "span":
            return
        attr = {k: (v or "") for k, v in attrs}
        classes = set(attr.get("class", "").split())
        if "article" in classes and "data-art-description" in attr:
            self.current = attr
            self.current_text = []
            self.line_no += 1

    def handle_data(self, data: str) -> None:
        if self.current is not None:
            self.current_text.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "span" and self.current is not None:
            text = "".join(self.current_text).strip()
            self.articles.append((self.line_no, self.current, text))
            self.current = None
            self.current_text = []


class PreParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_pre = False
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() == "pre":
            self.in_pre = True

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "pre":
            self.in_pre = False

    def handle_data(self, data: str) -> None:
        if self.in_pre:
            self.parts.append(data)


def parse_items(receipt_html: str) -> list[dict[str, Any]]:
    parser = ArticleParser()
    parser.feed(receipt_html or "")
    items: list[dict[str, Any]] = []
    for line_no, attrs, text in parser.articles:
        # A mennyiség × egységár sor külön span, utána jön a tényleges terméksor.
        if re.search(r"Ft\s*/\s*(db|kg)\b", text, re.IGNORECASE):
            continue
        description = attrs.get("data-art-description", "").strip()
        if not description:
            continue
        # A blokk ezreselválasztója NBSP; a normál szóköz az oszlopok közti kitöltés.
        # Így csak a sor legutolsó száma lesz a tételösszeg, a terméknévben lévő cikkszám nem.
        total_match = re.search(r"(-?\d(?:[\d\xa0]*\d)?)\s+[A-E]\d{2}\s*$", text, re.IGNORECASE)
        items.append(
            {
                "line_no": line_no,
                "article_id": attrs.get("data-art-id", ""),
                "description": description,
                "normalized": normalize(description),
                "quantity": parse_number(attrs.get("data-art-quantity")) or 1.0,
                "unit_price": parse_number(attrs.get("data-unit-price")),
                "item_total": parse_number(total_match.group(1)) if total_match else None,
                "tax_type": attrs.get("data-tax-type", ""),
            }
        )
    return items


def receipt_plain_text(receipt_html: str) -> str:
    parser = PreParser()
    parser.feed(receipt_html or "")
    text = html.unescape("".join(parser.parts)).replace("\xa0", " ")
    lines = [line.rstrip() for line in text.splitlines()]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def receipt_total_from_html(receipt_html: str) -> float | None:
    """A blokk végösszegének kinyerése a nyomtatott nyugtából.

    A Lidl lista/detail API egyes blokkoknál 0 vagy hiányzó totalAmount értéket ad,
    miközben a htmlPrintedReceipt tartalmazza a valós fizetendő összeget.
    """
    text = receipt_plain_text(receipt_html)
    patterns = (
        r"(?im)^\s*ÖSSZESEN:\s*(-?\d[\d ]*(?:,\d{1,2})?)\s*Ft\s*$",
        r"(?im)^\s*fizetendő\s+(-?\d[\d ]*(?:,\d{1,2})?)\s*Ft\s*$",
    )
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return parse_number(match.group(1))
    return None


class Database:
    def __init__(self, path: Path = DB_PATH) -> None:
        self.path = path
        self.connection = sqlite3.connect(path)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("PRAGMA foreign_keys=ON")
        self.connection.execute("PRAGMA journal_mode=WAL")
        self.connection.execute("PRAGMA synchronous=NORMAL")
        self._create_schema()
        self._repair_receipt_summaries()

    def _create_schema(self) -> None:
        self.connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS receipts (
                id TEXT PRIMARY KEY,
                receipt_date TEXT,
                total_amount REAL,
                articles_count INTEGER,
                store TEXT,
                receipt_html TEXT,
                indexed_ok INTEGER NOT NULL DEFAULT 0,
                indexed_at TEXT
            );

            CREATE TABLE IF NOT EXISTS items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                receipt_id TEXT NOT NULL,
                line_no INTEGER NOT NULL,
                article_id TEXT,
                description TEXT NOT NULL,
                normalized TEXT NOT NULL,
                quantity REAL,
                unit_price REAL,
                item_total REAL,
                tax_type TEXT,
                receipt_date TEXT,
                store TEXT,
                UNIQUE(receipt_id, line_no),
                FOREIGN KEY(receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_items_normalized ON items(normalized);
            CREATE INDEX IF NOT EXISTS idx_items_article ON items(article_id);
            CREATE INDEX IF NOT EXISTS idx_items_receipt ON items(receipt_id);
            CREATE INDEX IF NOT EXISTS idx_receipts_date ON receipts(receipt_date DESC);
            """
        )
        self.connection.commit()

    def _repair_receipt_summaries(self) -> None:
        """Megjavítja a régebben 0/hiányzó összeggel vagy tételszámmal mentett blokkokat.

        Nem kér le semmit a Lidltől: kizárólag a már helyben tárolt receipt_html alapján dolgozik.
        """
        rows = self.connection.execute(
            """
            SELECT id, total_amount, articles_count, receipt_html
            FROM receipts
            WHERE indexed_ok=1
              AND receipt_html IS NOT NULL AND receipt_html <> ''
              AND (total_amount IS NULL OR total_amount <= 0
                   OR articles_count IS NULL OR articles_count <= 0)
            """
        ).fetchall()
        if not rows:
            return
        with self.connection:
            for row in rows:
                receipt_html = row["receipt_html"] or ""
                total = row["total_amount"]
                count = row["articles_count"]
                if total is None or float(total or 0) <= 0:
                    parsed_total = receipt_total_from_html(receipt_html)
                    if parsed_total is not None:
                        total = parsed_total
                if count is None or int(count or 0) <= 0:
                    parsed_count = len(parse_items(receipt_html))
                    if parsed_count > 0:
                        count = parsed_count
                self.connection.execute(
                    "UPDATE receipts SET total_amount=?, articles_count=? WHERE id=?",
                    (total, count, row["id"]),
                )

    def close(self) -> None:
        self.connection.close()

    def get_meta(self, key: str, default: str = "") -> str:
        row = self.connection.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return row[0] if row else default

    def set_meta(self, key: str, value: Any) -> None:
        self.connection.execute(
            "INSERT INTO meta(key,value) VALUES(?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, str(value)),
        )
        self.connection.commit()

    def upsert_metadata(self, tickets: Iterable[dict[str, Any]]) -> list[str]:
        new_ids: list[str] = []
        for ticket in tickets:
            receipt_id = str(ticket.get("id", ""))
            if not receipt_id:
                continue
            exists = self.connection.execute("SELECT 1 FROM receipts WHERE id=?", (receipt_id,)).fetchone()
            if not exists:
                new_ids.append(receipt_id)
            self.connection.execute(
                """
                INSERT INTO receipts(id, receipt_date, total_amount, articles_count, store, indexed_ok)
                VALUES(?,?,?,?,?,0)
                ON CONFLICT(id) DO UPDATE SET
                    receipt_date=excluded.receipt_date,
                    total_amount=CASE
                        WHEN excluded.total_amount IS NOT NULL AND excluded.total_amount > 0
                        THEN excluded.total_amount ELSE receipts.total_amount END,
                    articles_count=CASE
                        WHEN excluded.articles_count IS NOT NULL AND excluded.articles_count > 0
                        THEN excluded.articles_count ELSE receipts.articles_count END,
                    store=excluded.store
                """,
                (
                    receipt_id,
                    ticket.get("date"),
                    ticket.get("totalAmount"),
                    ticket.get("articlesCount"),
                    ticket.get("store") or "",
                ),
            )
        self.connection.commit()
        return new_ids

    def all_receipt_ids(self) -> set[str]:
        return {row[0] for row in self.connection.execute("SELECT id FROM receipts")}

    def pending_rows(self) -> list[sqlite3.Row]:
        return self.connection.execute(
            "SELECT id, receipt_date, total_amount, articles_count, store "
            "FROM receipts WHERE indexed_ok=0 ORDER BY receipt_date DESC"
        ).fetchall()

    def save_detail(self, ticket: dict[str, Any], detail: dict[str, Any]) -> int:
        receipt = detail.get("ticket") or {}
        receipt_id = str(ticket.get("id") or receipt.get("id") or "")
        if not receipt_id:
            raise ValueError("Hiányzó blokkazonosító")
        receipt_html = receipt.get("htmlPrintedReceipt") or ""
        if not receipt_html:
            raise ValueError("A blokknak nincs HTML-tartalma")
        receipt_date = ticket.get("date") or receipt.get("date") or ""
        store = ticket.get("store") or ((receipt.get("store") or {}).get("name")) or ""
        items = parse_items(receipt_html)
        detail_total = ticket.get("totalAmount") or receipt.get("totalAmount") or receipt_total_from_html(receipt_html)
        detail_count = ticket.get("articlesCount") or receipt.get("articlesCount") or len(items)

        with self.connection:
            self.connection.execute("DELETE FROM items WHERE receipt_id=?", (receipt_id,))
            self.connection.execute(
                """
                INSERT INTO receipts(
                    id, receipt_date, total_amount, articles_count, store,
                    receipt_html, indexed_ok, indexed_at
                ) VALUES(?,?,?,?,?,?,1,?)
                ON CONFLICT(id) DO UPDATE SET
                    receipt_date=excluded.receipt_date,
                    total_amount=excluded.total_amount,
                    articles_count=excluded.articles_count,
                    store=excluded.store,
                    receipt_html=excluded.receipt_html,
                    indexed_ok=1,
                    indexed_at=excluded.indexed_at
                """,
                (
                    receipt_id,
                    receipt_date,
                    detail_total,
                    detail_count,
                    store,
                    receipt_html,
                    dt.datetime.now().astimezone().isoformat(timespec="seconds"),
                ),
            )
            for item in items:
                self.connection.execute(
                    """
                    INSERT INTO items(
                        receipt_id, line_no, article_id, description, normalized,
                        quantity, unit_price, item_total, tax_type, receipt_date, store
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        receipt_id,
                        item["line_no"],
                        item["article_id"],
                        item["description"],
                        item["normalized"],
                        item["quantity"],
                        item["unit_price"],
                        item["item_total"],
                        item["tax_type"],
                        receipt_date,
                        store,
                    ),
                )
        return len(items)

    def stats(self) -> dict[str, Any]:
        receipts = self.connection.execute(
            "SELECT COUNT(*) FROM receipts WHERE indexed_ok=1"
        ).fetchone()[0]
        pending = self.connection.execute(
            "SELECT COUNT(*) FROM receipts WHERE indexed_ok=0"
        ).fetchone()[0]
        items = self.connection.execute("SELECT COUNT(*) FROM items").fetchone()[0]
        distinct_items = self.connection.execute(
            "SELECT COUNT(DISTINCT CASE WHEN article_id <> '' THEN article_id ELSE normalized END) FROM items"
        ).fetchone()[0]
        return {
            "receipts": receipts,
            "pending": pending,
            "items": items,
            "distinct_items": distinct_items,
            "last_refresh": self.get_meta("last_refresh"),
            "full_sync_complete": self.get_meta("full_sync_complete", "0") == "1",
        }

    def search(self, query: str, limit: int = 300) -> list[sqlite3.Row]:
        tokens = [normalize(part) for part in query.split() if part.strip()]
        if not tokens:
            return []
        clauses: list[str] = []
        params: list[Any] = []
        for token in tokens:
            clauses.append(
                "(normalized LIKE ? OR lower(article_id) LIKE ? OR "
                "lower(store) LIKE ? OR lower(receipt_date) LIKE ?)"
            )
            wildcard = f"%{token}%"
            params.extend([wildcard, wildcard, wildcard, wildcard])
        params.append(limit)
        sql = f"""
            SELECT id, receipt_id, line_no, article_id, description, quantity,
                   unit_price, item_total, receipt_date, store
            FROM items
            WHERE {' AND '.join(clauses)}
            ORDER BY receipt_date DESC, id DESC
            LIMIT ?
        """
        return self.connection.execute(sql, params).fetchall()

    def receipt(self, receipt_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "SELECT * FROM receipts WHERE id=?", (receipt_id,)
        ).fetchone()

    def receipts(self, limit: int = 10000) -> list[sqlite3.Row]:
        return self.connection.execute(
            """
            SELECT id, receipt_date, total_amount, articles_count, store
            FROM receipts
            WHERE indexed_ok=1
            ORDER BY receipt_date DESC, id DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()

    def clear_index(self) -> None:
        with self.connection:
            self.connection.execute("DELETE FROM items")
            self.connection.execute("DELETE FROM receipts")
            self.connection.execute("DELETE FROM meta")


class BrowserBridgeError(RuntimeError):
    pass


def open_in_normal_firefox(url: str) -> None:
    """A felhasználó valódi Firefoxát nyitja meg; sem Playwright, sem külön profil nincs."""
    for executable in ("firefox", "firefox-esr"):
        path = shutil.which(executable)
        if path:
            try:
                subprocess.Popen(
                    [path, "--new-tab", url],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                return
            except OSError:
                pass
    webbrowser.open(url, new=2)


def open_login_page() -> None:
    print("Megnyitom a Lidl bejelentkezést a normál Firefoxban.")
    print("Belépés után indítsd újra a frissítést.")
    open_in_normal_firefox(LOGIN_URL)


def open_online(receipt_id: str) -> None:
    open_in_normal_firefox(DETAIL_URL.format(receipt_id=receipt_id))


def _ensure_v3_bridge_installed() -> None:
    missing: list[str] = []
    if not V3_HOST_MANIFEST.is_file():
        missing.append(str(V3_HOST_MANIFEST))
    if not V3_HOST_HELPER.is_file():
        missing.append(str(V3_HOST_HELPER))
    if missing:
        raise BrowserBridgeError(
            "A v3 Native Messaging host nincs telepítve. Hiányzik:\n  - "
            + "\n  - ".join(missing)
            + "\nFuttasd a v3.0.0 csomag install-v3.sh telepítőjét."
        )


def _new_run_id(prefix: str) -> str:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return f"{prefix}-{stamp}-{os.getpid()}-{secrets.token_hex(4)}"


def _run_dir(run_id: str) -> Path:
    return V3_RUNS_DIR / run_id


def _read_run_status(run_id: str) -> dict[str, Any] | None:
    path = _run_dir(run_id) / "status.json"
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    except (OSError, ValueError, json.JSONDecodeError):
        return None


def _cleanup_old_v3_runs(max_age_days: int = 7) -> None:
    cutoff = time.time() - max_age_days * 86400
    try:
        entries = list(V3_RUNS_DIR.iterdir())
    except OSError:
        return
    for entry in entries:
        try:
            if entry.is_dir() and entry.stat().st_mtime < cutoff:
                shutil.rmtree(entry, ignore_errors=True)
        except OSError:
            pass


def _wait_for_v3_run(run_id: str, timeout: int) -> dict[str, Any]:
    """Várakozás a bridge-re; a néma indulási és elakadt futási hibákat külön jelzi."""
    started = time.monotonic()
    deadline = started + timeout
    # Ha a kiegészítő egyáltalán nem válaszol, ne várjunk 10 percet.
    startup_timeout = min(30, timeout)
    stall_timeout = min(90, timeout)
    last_progress = started
    last_signature: tuple[Any, ...] | None = None
    last_line = ""
    last_wait_notice = 0
    while time.monotonic() < deadline:
        now = time.monotonic()
        status = _read_run_status(run_id)
        if status:
            state = str(status.get("state") or "")
            phase = str(status.get("phase") or "")
            signature = (
                state, phase, status.get("listPage"), status.get("detailDone"),
                status.get("updatedAt"), status.get("message"),
            )
            if signature != last_signature:
                last_signature = signature
                last_progress = now
            if phase == "list":
                line = (
                    f"Firefox: blokklista {status.get('listPage', 0)}/{status.get('totalPages', '?')}"
                    f" · új ezen az oldalon: {status.get('unknownOnPage', 0)}"
                )
            elif phase == "details":
                line = (
                    f"Firefox: blokkok {status.get('detailDone', 0)}/{status.get('detailTotal', 0)}"
                    f" · hibás: {status.get('failures', 0)}"
                )
            elif phase == "probe":
                line = f"Firefox: munkamenet ellenőrzése · HTTP {status.get('httpStatus', '?')}"
            else:
                line = str(status.get("message") or phase or state)
            if line and line != last_line:
                print(line, flush=True)
                last_line = line
            if state == "done":
                return status
            if state == "error":
                raise BrowserBridgeError(str(status.get("message") or "A Firefox bridge hibát jelzett."))
            if now - last_progress >= stall_timeout:
                raise BrowserBridgeError(
                    f"{int(stall_timeout)} másodperce nincs előrehaladás a Firefoxban "
                    f"(fázis: {phase or 'ismeretlen'}). A futás naplója: "
                    f"{_run_dir(run_id) / 'status.json'}"
                )
        elif now - started >= startup_timeout:
            raise BrowserBridgeError(
                f"{int(startup_timeout)} másodpercen belül semmilyen válasz nem érkezett "
                "a Firefox kiegészítőtől.\n"
                "Ellenőrizd az about:addons oldalon, hogy a Lidl blokkkereső v3 aktív-e; "
                "a megnyílt Lidl-lap címsorában megmaradt-e az lbk_v3_run= paraméter; "
                "és megjelent-e a jobb alsó sarokban a kiegészítő állapotjelzője.\n"
                "Részletes hibák: about:debugging#/runtime/this-firefox → Lidl blokkkereső → Inspect. "
                f"Futás: {_run_dir(run_id)}"
            )
        # Csak tájékoztat: a felhasználó lássa, hogy nem fagyott le a TUI.
        elapsed = int(now - started)
        if elapsed >= 5 and elapsed // 15 > last_wait_notice and not status:
            last_wait_notice = elapsed // 15
            print(f"Firefox válaszára várakozás: {elapsed}/{int(startup_timeout)} mp…", flush=True)
        time.sleep(0.25)

    raise BrowserBridgeError(
        f"Időtúllépés ({timeout} mp). Utolsó állapot: "
        f"{_run_dir(run_id) / 'status.json'}. "
        "A Firefox tovább dolgozhat; új szinkron előtt ellenőrizd az állapotát."
    )


def _trigger_url(run_id: str, mode: str | None = None, probe: bool = False) -> str:
    suffix = f"&lbk_v3_run={run_id}"
    if probe:
        suffix += "&lbk_v3_probe=1"
    else:
        suffix += f"&lbk_v3_mode={mode or 'incremental'}"
    suffix += f"&lbk_v3_ts={int(time.time())}"
    return HOME_URL + suffix


def print_firefox_info() -> None:
    print("Firefox v3 bridge:")
    print(f"- Native host manifest: {V3_HOST_MANIFEST} · {'OK' if V3_HOST_MANIFEST.is_file() else 'HIÁNYZIK'}")
    print(f"- Native host helper:   {V3_HOST_HELPER} · {'OK' if V3_HOST_HELPER.is_file() else 'HIÁNYZIK'}")
    print(f"- Extension ID:         {V3_EXTENSION_ID}")
    print("- Az extension tényleges futását a --session-status ellenőrzi.")


def session_status() -> bool:
    try:
        _ensure_v3_bridge_installed()
        _cleanup_old_v3_runs()
        run_id = _new_run_id("probe")
        _run_dir(run_id).mkdir(parents=True, exist_ok=True)
        print("Normál Firefox Lidl-munkamenetének ellenőrzése v3 bridge-dzsel…")
        open_in_normal_firefox(_trigger_url(run_id, probe=True))
        status = _wait_for_v3_run(run_id, V3_PROBE_TIMEOUT_SECONDS)
        http_status = int(status.get("httpStatus") or 0)
        if http_status == 200 and status.get("ok"):
            print(
                "Érvényes Lidl-munkamenet · "
                f"HTTP 200 · totalCount: {status.get('totalCount', '?')}"
            )
            if not V3_KEEP_RUNS:
                shutil.rmtree(_run_dir(run_id), ignore_errors=True)
            return True
        print(f"Nincs érvényes Lidl-munkamenet (HTTP {http_status}).")
        if not V3_KEEP_RUNS:
            shutil.rmtree(_run_dir(run_id), ignore_errors=True)
        return False
    except BrowserBridgeError as error:
        print(f"HIBA: {error}")
        return False

def chunks(values: list[Any], size: int) -> Iterable[list[Any]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


def sync_index(database: Database, full: bool = False) -> None:
    print("\nLidl indexfrissítés · v3 Firefox bridge")
    print("=" * 60)
    _ensure_v3_bridge_installed()
    _cleanup_old_v3_runs()

    mode = "full" if full else "incremental"
    if full:
        print("Teljes listaellenőrzés a normál Firefoxban.")
    else:
        print("Inkrementális frissítés a normál Firefoxban.")

    run_id = _new_run_id("sync")
    run_dir = _run_dir(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)
    trigger = _trigger_url(run_id, mode=mode)
    open_in_normal_firefox(trigger)

    status = _wait_for_v3_run(run_id, V3_SYNC_TIMEOUT_SECONDS)
    details_dir = run_dir / "details"
    detail_files = sorted(details_dir.glob("*.json")) if details_dir.is_dir() else []

    imported = 0
    failures = 0
    item_total = 0
    for index, detail_file in enumerate(detail_files, start=1):
        try:
            payload = json.loads(detail_file.read_text(encoding="utf-8"))
            if not payload.get("ok"):
                failures += 1
                print(f"  HIBÁS blokk {payload.get('receiptId', '?')}: {payload.get('error', 'ismeretlen hiba')}")
                continue
            ticket = payload.get("ticket")
            detail = payload.get("detail")
            if not isinstance(ticket, dict) or not isinstance(detail, dict):
                raise ValueError("hiányos detail payload")
            item_total += database.save_detail(ticket, detail)
            imported += 1
        except Exception as error:
            failures += 1
            print(f"  HIBÁS detail fájl {detail_file.name}: {error}")
        print(f"Helyi indexelés: {index}/{len(detail_files)} · hibás: {failures}", end="\r", flush=True)
    if detail_files:
        print()

    if full or bool(status.get("reachedLastPage")):
        database.set_meta("full_sync_complete", "1")
    database.set_meta("last_refresh", dt.datetime.now().astimezone().isoformat(timespec="seconds"))
    stats = database.stats()

    if not detail_files and int(status.get("pendingCount") or 0) == 0:
        print(f"Nincs feldolgozatlan új blokk. Index: {stats['receipts']} blokk, {stats['items']} tétel.")
        if not V3_KEEP_RUNS:
            shutil.rmtree(run_dir, ignore_errors=True)
        return

    print(
        f"Kész. {stats['receipts']} blokk, {stats['items']} tétel. "
        f"Most indexelt blokk: {imported}; tétel: {item_total}; "
        f"Firefox-hiba: {int(status.get('failures') or 0)}; helyi hiba: {failures}; "
        f"függő blokk: {stats['pending']}."
    )
    if not V3_KEEP_RUNS and failures == 0 and int(status.get("failures") or 0) == 0:
        shutil.rmtree(run_dir, ignore_errors=True)

def terminal_pause(message: str = "Folytatáshoz nyomj ENTER-t…") -> None:
    try:
        input(message)
    except EOFError:
        pass


def wrap_text(value: str, width: int) -> list[str]:
    return textwrap.wrap(value, max(10, width), replace_whitespace=False) or [""]


class Tui:
    def __init__(self, database: Database) -> None:
        self.db = database
        self.query = ""
        self.results: list[sqlite3.Row] = []
        self.selected = 0
        self.offset = 0
        self.message = "Írj be keresést a / billentyűvel."

    def run(self) -> None:
        curses.wrapper(self._main)

    def _colors(self) -> None:
        if not curses.has_colors():
            return
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_BLUE, -1)
        curses.init_pair(2, curses.COLOR_YELLOW, -1)
        curses.init_pair(3, curses.COLOR_RED, -1)
        curses.init_pair(4, curses.COLOR_CYAN, -1)

    def _main(self, screen: Any) -> None:
        self._colors()
        curses.curs_set(0)
        screen.keypad(True)
        while True:
            self._draw(screen)
            key = screen.getch()
            if key in (ord("q"), ord("Q")):
                return
            if key == ord("/"):
                self._input_query(screen)
            elif key in (curses.KEY_DOWN, ord("j")):
                if self.results:
                    self.selected = min(len(self.results) - 1, self.selected + 1)
            elif key in (curses.KEY_UP, ord("k")):
                if self.results:
                    self.selected = max(0, self.selected - 1)
            elif key in (10, 13, curses.KEY_ENTER):
                if self.results:
                    self._receipt_view(screen, self.results[self.selected]["receipt_id"])
            elif key in (ord("r"), curses.KEY_F5):
                self._external_action(screen, lambda: sync_index(self.db, full=False))
                self._refresh_results()
            elif key == ord("R"):
                if self._confirm(screen, "Teljes listaellenőrzést indítsak? A meglévő index megmarad."):
                    self._external_action(screen, lambda: sync_index(self.db, full=True))
                    self._refresh_results()
            elif key == ord("l"):
                self._receipt_list_view(screen)
            elif key == ord("L"):
                self._external_action(screen, open_login_page)
            elif key in (ord("o"), ord("O")) and self.results:
                receipt_id = self.results[self.selected]["receipt_id"]
                self._external_action(screen, lambda: open_online(receipt_id))
            elif key in (ord("s"), ord("S")):
                self._stats_popup(screen)
            elif key in (ord("D"),):
                if self._confirm(screen, "BIZTOSAN törlöd a teljes helyi blokkindexet?"):
                    self.db.clear_index()
                    self.results = []
                    self.query = ""
                    self.message = "A helyi index törölve."

    def _refresh_results(self) -> None:
        self.results = self.db.search(self.query) if self.query else []
        self.selected = min(self.selected, max(0, len(self.results) - 1))
        self.offset = 0

    def _draw(self, screen: Any) -> None:
        screen.erase()
        height, width = screen.getmaxyx()
        if height < 16 or width < 72:
            screen.addstr(0, 0, "A terminál legyen legalább 72×16 karakteres.")
            screen.refresh()
            return
        stats = self.db.stats()
        title = f" {APP_NAME} · Linux V{APP_VERSION} "
        screen.attron(curses.A_BOLD | (curses.color_pair(1) if curses.has_colors() else 0))
        screen.addnstr(0, 0, title, width - 1)
        screen.attroff(curses.A_BOLD | (curses.color_pair(1) if curses.has_colors() else 0))
        screen.addnstr(
            1,
            0,
            f" {stats['receipts']} blokk · {stats['items']} tétel · {stats['distinct_items']} különböző · függő: {stats['pending']}",
            width - 1,
        )
        last = pretty_date(stats["last_refresh"]) if stats["last_refresh"] else "még nem volt"
        screen.addnstr(2, 0, f" Utolsó frissítés: {last}", width - 1)
        screen.hline(3, 0, curses.ACS_HLINE, width)
        screen.addnstr(4, 0, f" Keresés: {self.query or '—'}", width - 1, curses.A_BOLD)
        screen.addnstr(5, 0, f" Találatok: {len(self.results)}", width - 1)

        list_top = 7
        list_bottom = height - 4
        visible = max(1, list_bottom - list_top)
        if self.selected < self.offset:
            self.offset = self.selected
        elif self.selected >= self.offset + visible:
            self.offset = self.selected - visible + 1

        for display_row, result_index in enumerate(range(self.offset, min(len(self.results), self.offset + visible))):
            row = self.results[result_index]
            line = (
                f"{pretty_date(row['receipt_date'])[:10]} · "
                f"{row['description']} · {money(row['unit_price'])} · {row['store']}"
            )
            attr = curses.A_REVERSE if result_index == self.selected else curses.A_NORMAL
            screen.addnstr(list_top + display_row, 1, line, width - 3, attr)

        screen.hline(height - 3, 0, curses.ACS_HLINE, width)
        help_line = "/ keres · ↑↓ · ENTER blokk · r frissít · R teljes · l blokkok · L belépés · o online · s stat · D index · q vége"
        screen.addnstr(height - 2, 0, help_line, width - 1)
        screen.addnstr(height - 1, 0, " " + self.message, width - 1, curses.A_DIM)
        screen.refresh()

    def _input_query(self, screen: Any) -> None:
        height, width = screen.getmaxyx()
        prompt = "Keresés: "
        screen.move(height - 1, 0)
        screen.clrtoeol()
        screen.addstr(height - 1, 0, prompt)
        curses.echo()
        curses.curs_set(1)
        try:
            raw = screen.getstr(height - 1, len(prompt), max(1, width - len(prompt) - 2))
            self.query = raw.decode("utf-8", errors="replace").strip()
        finally:
            curses.noecho()
            curses.curs_set(0)
        self.results = self.db.search(self.query) if self.query else []
        self.selected = 0
        self.offset = 0
        self.message = f"{len(self.results)} találat."

    def _external_action(self, screen: Any, action: Any) -> None:
        # Ctrl+C esetén is mindig állítsuk helyre a curses terminált.
        # A háttérben megnyitott Firefox-lap ettől még futhat; az index biztonságban marad.
        suspended = False
        interrupted = False
        try:
            curses.def_prog_mode()
            curses.endwin()
            suspended = True
            try:
                action()
            except KeyboardInterrupt:
                interrupted = True
                print("\nMűvelet megszakítva (Ctrl+C). A Firefox-lap még dolgozhat; "
                      "új szinkron előtt várd meg, amíg befejezi.", flush=True)
            except Exception as error:
                print(f"\nHIBA: {error}", file=sys.stderr, flush=True)
            if not interrupted:
                print("\n3 másodperc múlva visszatérek a TUI-hoz…", flush=True)
                time.sleep(3)
        finally:
            if suspended:
                try:
                    curses.reset_prog_mode()
                    curses.curs_set(0)
                    screen.clear()
                except curses.error:
                    # Ha a terminál közben bezárult, a kilépést ne nyomja el
                    # egy másodlagos curses-hiba.
                    pass


    def _confirm(self, screen: Any, question: str) -> bool:
        height, width = screen.getmaxyx()
        box_width = min(width - 4, max(50, len(question) + 6))
        box = curses.newwin(5, box_width, max(0, (height - 5) // 2), max(0, (width - box_width) // 2))
        box.box()
        box.addnstr(1, 2, question, box_width - 4)
        box.addstr(3, 2, "i = igen, bármi más = nem")
        box.refresh()
        return box.getch() in (ord("i"), ord("I"))

    def _stats_popup(self, screen: Any) -> None:
        stats = self.db.stats()
        lines = [
            "STATISZTIKA",
            f"Indexelt blokkok: {stats['receipts']}",
            f"Terméktételek: {stats['items']}",
            f"Különböző termékek: {stats['distinct_items']}",
            f"Függő/hibás blokkok: {stats['pending']}",
            f"Teljes lista elkészült: {'igen' if stats['full_sync_complete'] else 'nem'}",
            f"Utolsó frissítés: {pretty_date(stats['last_refresh']) if stats['last_refresh'] else '–'}",
            "",
            "Bezárás: bármely billentyű",
        ]
        height, width = screen.getmaxyx()
        box_width = min(width - 4, 64)
        box_height = min(height - 2, len(lines) + 4)
        box = curses.newwin(box_height, box_width, (height - box_height) // 2, (width - box_width) // 2)
        box.box()
        for index, line in enumerate(lines[: box_height - 2], start=1):
            box.addnstr(index, 2, line, box_width - 4, curses.A_BOLD if index == 1 else curses.A_NORMAL)
        box.refresh()
        box.getch()

    def _receipt_list_view(self, screen: Any) -> None:
        receipts = self.db.receipts()
        if not receipts:
            self.message = "Nincs letöltött blokk."
            return

        selected = 0
        offset = 0
        while True:
            screen.erase()
            height, width = screen.getmaxyx()
            screen.addnstr(0, 0, f" Letöltött Lidl blokkok · {len(receipts)} db ", width - 1, curses.A_BOLD)
            screen.hline(1, 0, curses.ACS_HLINE, width)

            list_top = 2
            list_bottom = height - 2
            visible = max(1, list_bottom - list_top)
            if selected < offset:
                offset = selected
            elif selected >= offset + visible:
                offset = selected - visible + 1

            for display_row, receipt_index in enumerate(
                range(offset, min(len(receipts), offset + visible))
            ):
                row = receipts[receipt_index]
                date_text = pretty_date(row["receipt_date"])
                count_text = f"{row['articles_count']} tétel" if row["articles_count"] is not None else "– tétel"
                line = (
                    f"{date_text} · {money(row['total_amount'])} · "
                    f"{count_text} · {row['store'] or '–'}"
                )
                attr = curses.A_REVERSE if receipt_index == selected else curses.A_NORMAL
                screen.addnstr(list_top + display_row, 1, line, width - 3, attr)

            screen.hline(height - 2, 0, curses.ACS_HLINE, width)
            screen.addnstr(
                height - 1,
                0,
                "↑↓/PgUp/PgDn · ENTER blokk · o online · q vissza",
                width - 1,
            )
            screen.refresh()

            key = screen.getch()
            if key in (ord("q"), ord("Q"), 27, curses.KEY_LEFT):
                return
            if key in (curses.KEY_DOWN, ord("j")):
                selected = min(len(receipts) - 1, selected + 1)
            elif key in (curses.KEY_UP, ord("k")):
                selected = max(0, selected - 1)
            elif key == curses.KEY_NPAGE:
                selected = min(len(receipts) - 1, selected + visible)
            elif key == curses.KEY_PPAGE:
                selected = max(0, selected - visible)
            elif key in (10, 13, curses.KEY_ENTER):
                self._receipt_view(screen, receipts[selected]["id"])
            elif key in (ord("o"), ord("O")):
                self._external_action(screen, lambda: open_online(receipts[selected]["id"]))

    def _receipt_view(self, screen: Any, receipt_id: str) -> None:
        receipt = self.db.receipt(receipt_id)
        if not receipt:
            self.message = "A blokk nem található."
            return
        text = receipt_plain_text(receipt["receipt_html"] or "")
        lines = text.splitlines() or ["A blokk üres."]
        top = 0
        while True:
            screen.erase()
            height, width = screen.getmaxyx()
            header = f" Lidl blokk · {pretty_date(receipt['receipt_date'])} · {receipt['store']} · {money(receipt['total_amount'])} "
            screen.addnstr(0, 0, header, width - 1, curses.A_BOLD)
            screen.hline(1, 0, curses.ACS_HLINE, width)
            visible = height - 4
            for row_index, line in enumerate(lines[top : top + visible], start=2):
                screen.addnstr(row_index, 0, line, width - 1)
            screen.hline(height - 2, 0, curses.ACS_HLINE, width)
            screen.addnstr(height - 1, 0, "↑↓/PgUp/PgDn görget · o online megnyitás · q vissza", width - 1)
            screen.refresh()
            key = screen.getch()
            if key in (ord("q"), ord("Q"), ord("b"), ord("B"), 27, curses.KEY_LEFT):
                return
            if key in (curses.KEY_DOWN, ord("j")):
                top = min(max(0, len(lines) - visible), top + 1)
            elif key in (curses.KEY_UP, ord("k")):
                top = max(0, top - 1)
            elif key == curses.KEY_NPAGE:
                top = min(max(0, len(lines) - visible), top + visible)
            elif key == curses.KEY_PPAGE:
                top = max(0, top - visible)
            elif key in (ord("o"), ord("O")):
                self._external_action(screen, lambda: open_online(receipt_id))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=APP_NAME)
    parser.add_argument("--login", action="store_true", help="Lidl-belépés megnyitása a normál böngészőben")
    parser.add_argument("--session-status", action="store_true", help="Lidl-munkamenet ellenőrzése a v3 Firefox bridge-dzsel")
    parser.add_argument("--sync", action="store_true", help="Inkrementális frissítés")
    parser.add_argument("--full-sync", action="store_true", help="Teljes listaellenőrzés")
    parser.add_argument("--search", metavar="SZÖVEG", help="Nem interaktív keresés")
    parser.add_argument("--stats", action="store_true", help="Statisztika kiírása")
    parser.add_argument("--clear-index", action="store_true", help="Helyi index törlése")
    parser.add_argument("--browser-info", action="store_true", help="v3 Firefox/Native Messaging bridge állapota")
    parser.add_argument("--extension-path", action="store_true", help="A v3 Firefox extension manifest útvonalának kiírása")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    database = Database()
    try:
        if args.browser_info:
            print_firefox_info()
            return 0
        if args.extension_path:
            print(Path.home() / ".local/share/lidl-blokkkereso-v3/extension/manifest.json")
            return 0
        if args.login:
            open_login_page()
            return 0
        if args.session_status:
            return 0 if session_status() else 1
        if args.sync:
            sync_index(database, full=False)
            return 0
        if args.full_sync:
            sync_index(database, full=True)
            return 0
        if args.clear_index:
            answer = input("BIZTOSAN törlöd a helyi blokkindexet? Írd be: TORLES\n> ")
            if answer == "TORLES":
                database.clear_index()
                print("A helyi index törölve.")
            return 0
        if args.stats:
            print(json.dumps(database.stats(), ensure_ascii=False, indent=2))
            return 0
        if args.search is not None:
            rows = database.search(args.search)
            for row in rows:
                print(
                    f"{pretty_date(row['receipt_date'])}\t{row['description']}\t"
                    f"{money(row['unit_price'])}\t{row['store']}\t{row['receipt_id']}"
                )
            return 0
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            print("A TUI-hoz terminál szükséges. Használható: --sync, --full-sync, --search, --stats, --login, --session-status, --browser-info")
            return 2
        try:
            Tui(database).run()
        except KeyboardInterrupt:
            print("\nKilépés (Ctrl+C).")
        return 0
    finally:
        database.close()


if __name__ == "__main__":
    raise SystemExit(main())

__LIDL_PYTHON_APP_END__
__LIDL_PYTHON_PAYLOAD__
