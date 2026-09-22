#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import struct
import sys
from pathlib import Path
from typing import Any

DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "lidl-blokkkereso"
DB_PATH = DATA_DIR / "lidl_receipts.sqlite3"
RUNS_DIR = DATA_DIR / "v3-runs"
RUN_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,160}$")
RECEIPT_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,160}$")


def read_message() -> dict[str, Any] | None:
    raw_len = sys.stdin.buffer.read(4)
    if not raw_len:
        return None
    if len(raw_len) != 4:
        raise EOFError("Hiányos Native Messaging fejléc")
    length = struct.unpack("<I", raw_len)[0]
    raw = sys.stdin.buffer.read(length)
    if len(raw) != length:
        raise EOFError("Hiányos Native Messaging üzenet")
    value = json.loads(raw.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("A Native Messaging üzenet nem objektum")
    return value


def write_message(message: dict[str, Any]) -> None:
    raw = json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(raw)))
    sys.stdout.buffer.write(raw)
    sys.stdout.buffer.flush()


def safe_run_id(value: Any) -> str:
    run_id = str(value or "")
    if not RUN_ID_RE.fullmatch(run_id):
        raise ValueError("Érvénytelen runId")
    return run_id


def run_dir(run_id: str) -> Path:
    path = RUNS_DIR / run_id
    path.mkdir(parents=True, exist_ok=True)
    return path


def read_status(run_id: str) -> dict[str, Any]:
    path = run_dir(run_id) / "status.json"
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, json.JSONDecodeError):
        return {}


def write_status(run_id: str, **changes: Any) -> dict[str, Any]:
    path = run_dir(run_id) / "status.json"
    status = read_status(run_id)
    status.update(changes)
    status["runId"] = run_id
    status["updatedAt"] = dt.datetime.now().astimezone().isoformat(timespec="seconds")
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(path)
    return status


def db_connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH, timeout=15)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys=ON")
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute("PRAGMA synchronous=NORMAL")
    connection.executescript(
        """
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
        CREATE INDEX IF NOT EXISTS idx_receipts_date ON receipts(receipt_date DESC);
        """
    )
    connection.commit()
    return connection


def upsert_page(items: list[dict[str, Any]]) -> list[str]:
    ids = [str(item.get("id") or "") for item in items if item.get("id")]
    known: set[str] = set()
    with db_connect() as connection:
        if ids:
            placeholders = ",".join("?" for _ in ids)
            rows = connection.execute(f"SELECT id FROM receipts WHERE id IN ({placeholders})", ids).fetchall()
            known = {str(row[0]) for row in rows}
        for ticket in items:
            receipt_id = str(ticket.get("id") or "")
            if not receipt_id:
                continue
            connection.execute(
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
    return [receipt_id for receipt_id in ids if receipt_id not in known]


def pending_tickets() -> list[dict[str, Any]]:
    with db_connect() as connection:
        rows = connection.execute(
            """
            SELECT id, receipt_date, total_amount, articles_count, store
            FROM receipts
            WHERE indexed_ok=0
            ORDER BY receipt_date DESC, id DESC
            """
        ).fetchall()
        return [
            {
                "id": row["id"],
                "date": row["receipt_date"],
                "totalAmount": row["total_amount"],
                "articlesCount": row["articles_count"],
                "store": row["store"],
            }
            for row in rows
        ]


def save_detail_payload(run_id: str, msg: dict[str, Any]) -> tuple[Path, bool]:
    receipt_id = str(msg.get("receiptId") or "")
    if not RECEIPT_ID_RE.fullmatch(receipt_id):
        raise ValueError("Érvénytelen receiptId")
    details = run_dir(run_id) / "details"
    details.mkdir(parents=True, exist_ok=True)
    path = details / f"{receipt_id}.json"
    existed = path.exists()
    payload = {
        "receiptId": receipt_id,
        "ticket": msg.get("ticket"),
        "httpStatus": msg.get("httpStatus"),
        "ok": bool(msg.get("ok")),
        "detail": msg.get("detail"),
        "error": msg.get("error"),
        "at": msg.get("at"),
    }
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(path)
    return path, existed


def handle(msg: dict[str, Any]) -> dict[str, Any]:
    action = str(msg.get("action") or "")
    run_id = safe_run_id(msg.get("runId"))

    if action == "probe_result":
        ok = bool(msg.get("ok")) and int(msg.get("httpStatus") or 0) == 200
        write_status(
            run_id,
            state="done" if ok else "error",
            phase="probe",
            message="Firefox Lidl-munkamenet rendben." if ok else f"Lidl API HTTP {msg.get('httpStatus')}",
            httpStatus=msg.get("httpStatus"),
            ok=ok,
            page=msg.get("page"),
            size=msg.get("size"),
            totalCount=msg.get("totalCount"),
            itemsCount=msg.get("itemsCount"),
        )
        return {"ok": True}

    if action == "list_page":
        items = msg.get("items")
        if not isinstance(items, list):
            raise ValueError("Hiányzó blokklista")
        clean_items = [item for item in items if isinstance(item, dict)]
        unknown = upsert_page(clean_items)
        page = int(msg.get("page") or 1)
        total_pages = max(1, int(msg.get("totalPages") or 1))
        mode = str(msg.get("mode") or "incremental")
        continue_list = page < total_pages and (mode == "full" or len(unknown) > 0)
        write_status(
            run_id,
            state="running",
            phase="list",
            message="Blokklista letöltése a Firefoxban.",
            mode=mode,
            listPage=page,
            totalPages=total_pages,
            totalCount=int(msg.get("totalCount") or 0),
            unknownOnPage=len(unknown),
        )
        return {"ok": True, "unknownCount": len(unknown), "continueList": continue_list}

    if action == "list_done":
        pending = pending_tickets()
        write_status(
            run_id,
            state="running",
            phase="details",
            message="Blokkrészletek letöltése a Firefoxban.",
            mode=msg.get("mode"),
            listPage=msg.get("lastPageFetched"),
            totalPages=msg.get("totalPages"),
            totalCount=msg.get("totalCount"),
            reachedLastPage=bool(msg.get("reachedLastPage")),
            pendingCount=len(pending),
            detailDone=0,
            detailTotal=len(pending),
            failures=0,
        )
        return {"ok": True, "pending": pending}

    if action == "detail_result":
        _, existed = save_detail_payload(run_id, msg)
        status = read_status(run_id)
        done = int(status.get("detailDone") or 0) + (0 if existed else 1)
        failures = int(status.get("failures") or 0) + (0 if msg.get("ok") else (0 if existed else 1))
        write_status(
            run_id,
            state="running",
            phase="details",
            detailDone=done,
            detailTotal=int(msg.get("detailTotal") or status.get("detailTotal") or 0),
            failures=failures,
        )
        return {"ok": True, "stored": True}

    if action == "sync_done":
        write_status(
            run_id,
            state="done",
            phase="done",
            message="Firefox szinkron kész.",
            mode=msg.get("mode"),
            totalCount=msg.get("totalCount"),
            totalPages=msg.get("totalPages"),
            reachedLastPage=bool(msg.get("reachedLastPage")),
            pendingCount=int(msg.get("pendingCount") or 0),
            detailDone=int(msg.get("pendingCount") or 0),
            detailTotal=int(msg.get("pendingCount") or 0),
            failures=int(msg.get("failures") or 0),
        )
        return {"ok": True}

    if action == "sync_error":
        write_status(
            run_id,
            state="error",
            phase="error",
            message=str(msg.get("message") or "Ismeretlen Firefox sync hiba"),
        )
        return {"ok": True}

    return {"ok": False, "error": "ismeretlen action"}


def main() -> int:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    try:
        msg = read_message()
        if msg is None:
            return 0
        try:
            response = handle(msg)
        except Exception as error:
            run_id = str(msg.get("runId") or "")
            if RUN_ID_RE.fullmatch(run_id):
                try:
                    write_status(run_id, state="error", phase="error", message=str(error))
                except Exception:
                    pass
            response = {"ok": False, "error": str(error)}
        write_message(response)
        return 0
    except Exception as error:
        try:
            write_message({"ok": False, "error": str(error)})
        except Exception:
            pass
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
