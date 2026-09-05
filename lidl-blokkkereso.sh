#!/usr/bin/env bash
set -Eeuo pipefail

# V2.6: blokkösszeg/tételszám javítása a mentett nyugta HTML-ből; a 0/hiányzó API-metaadat nem ír felül jó helyi adatot.

APP_ID="lidl-blokkkereso"
APP_NAME="Lidl blokk- és termékkereső"
APP_VERSION="2.7.0"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_ID}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_ID}"
VENV_DIR="$DATA_DIR/venv"
PY_APP="$CACHE_DIR/lidl_app.py"
INSTALL_PATH="$HOME/.local/bin/$APP_ID"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_ID.desktop"

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
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  info "Telepítve: $INSTALL_PATH"
  info "Az alkalmazásmenüben keresd: $APP_NAME"
  exit 0
}

uninstall_desktop() {
  rm -f -- "$INSTALL_PATH" "$DESKTOP_FILE"
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
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
A program a felhasználó saját Lidl-fiókjával, saját gépén működik.
A helyi index és hitelesítőadatok a felhasználó saját profiljában maradnak.
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

command -v python3 >/dev/null 2>&1 || err "A python3 nincs telepítve. Ubuntu/Debian: sudo apt install python3 python3-venv"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  info "Első indítás: elkészítem a saját Python-környezetet…"
  if ! python3 -m venv "$VENV_DIR"; then
    err "Nem sikerült Python virtuális környezetet létrehozni. Ubuntu/Debian: sudo apt install python3-venv"
  fi
fi

PYTHON="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/pip"

if ! "$PYTHON" -c 'import playwright, keyring; from cryptography.fernet import Fernet' >/dev/null 2>&1; then
  info "Első indítás: telepítem a böngésző- és hitelesítőmodulokat…"
  "$PIP" install --disable-pip-version-check --upgrade pip setuptools wheel
  "$PIP" install --disable-pip-version-check playwright keyring cryptography
fi

# A Chromium-alapú automatizált munkamenetet a Lidl belépési oldala
# egyes gépeken korlátozza. A V2.3 ezért a Playwright saját Firefoxát használja.
FIREFOX_EXEC="$($PYTHON - <<'PYFIREFOX'
from pathlib import Path
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    print(p.firefox.executable_path)
PYFIREFOX
)"

if [[ ! -x "$FIREFOX_EXEC" ]]; then
  info "Első Firefox-indítás: letöltöm a Playwright Firefox böngészőt…"
  if ! "$VENV_DIR/bin/playwright" install firefox; then
    err "A Playwright Firefox telepítése nem sikerült. Ellenőrizd az internetkapcsolatot, majd indítsd újra."
  fi
fi

export LIDL_BROWSER_ENGINE="firefox"

# A Python-rész mindig újraírásra kerül, így a .sh frissítése automatikusan frissíti az alkalmazást is.
awk '/^__LIDL_PYTHON_APP_BEGIN__$/ {found=1; next} /^__LIDL_PYTHON_APP_END__$/ {found=0} found {print}' "$0" > "$PY_APP"
chmod 600 "$PY_APP"

exec "$PYTHON" "$PY_APP" "$@"
exit 0

: <<'__LIDL_PYTHON_PAYLOAD__'
__LIDL_PYTHON_APP_BEGIN__
from __future__ import annotations

import argparse
import base64
import curses
import datetime as dt
import getpass
import hashlib
import html
import json
import locale
import os
import re
import shutil
import sqlite3
import sys
import textwrap
import time
import unicodedata
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable

import keyring
from cryptography.fernet import Fernet, InvalidToken
from playwright.sync_api import BrowserContext, Page, Playwright, sync_playwright

APP_NAME = "Lidl blokk- és termékkereső"
APP_VERSION = "2.7.0"
BASE_URL = "https://www.lidl.hu"
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
PROFILE_DIR = DATA_DIR / "browser-profile-firefox"
CREDENTIAL_FILE = DATA_DIR / "credentials.enc"
AUTH_STATE_FILE = DATA_DIR / "auth-state.json"
KEYRING_SERVICE = "hu.attila.lidlkereso"
BROWSER_ENGINE = os.environ.get("LIDL_BROWSER_ENGINE", "firefox")
BROWSER_ENGINE_MARKER = DATA_DIR / "browser-engine.txt"
CONCURRENCY = 1
REQUEST_DELAY_SECONDS = 0.8
MAX_REQUEST_RETRIES = 4
AUTH_COOLDOWN_SECONDS = 0
AUTOLOGIN_ATTEMPTS = 2
AUTOLOGIN_RETRY_DELAY_SECONDS = 8

DATA_DIR.mkdir(parents=True, exist_ok=True)
PROFILE_DIR.mkdir(parents=True, exist_ok=True)

try:
    locale.setlocale(locale.LC_ALL, "")
except locale.Error:
    pass



class CredentialStore:
    """Mentett Lidl-fiók: rendszerkulcstartó, ennek hiányában titkosított helyi fájl."""

    USER_KEY = "lidl_username"
    PASSWORD_KEY = "lidl_password"

    @staticmethod
    def _fallback_fernet() -> Fernet:
        machine_id = "unknown-machine"
        for candidate in (Path("/etc/machine-id"), Path("/var/lib/dbus/machine-id")):
            try:
                value = candidate.read_text(encoding="utf-8").strip()
                if value:
                    machine_id = value
                    break
            except OSError:
                continue
        material = f"{machine_id}|{os.getuid()}|{Path.home()}|{KEYRING_SERVICE}|v1".encode("utf-8")
        return Fernet(base64.urlsafe_b64encode(hashlib.sha256(material).digest()))

    @classmethod
    def _keyring_usable(cls) -> bool:
        try:
            backend = keyring.get_keyring()
            name = f"{backend.__class__.__module__}.{backend.__class__.__name__}".lower()
            priority = float(getattr(backend, "priority", 0) or 0)
            return priority > 0 and "fail" not in name and "null" not in name
        except Exception:
            return False

    @classmethod
    def save(cls, username: str, password: str) -> str:
        username = username.strip()
        if not username or not password:
            raise ValueError("A felhasználónév és a jelszó nem lehet üres.")
        if cls._keyring_usable():
            try:
                keyring.set_password(KEYRING_SERVICE, cls.USER_KEY, username)
                keyring.set_password(KEYRING_SERVICE, cls.PASSWORD_KEY, password)
                CREDENTIAL_FILE.unlink(missing_ok=True)
                return "Linux rendszerkulcstartó"
            except Exception:
                pass
        payload = json.dumps({"username": username, "password": password}, ensure_ascii=False).encode("utf-8")
        CREDENTIAL_FILE.write_bytes(cls._fallback_fernet().encrypt(payload))
        os.chmod(CREDENTIAL_FILE, 0o600)
        return f"titkosított helyi fájl ({CREDENTIAL_FILE})"

    @classmethod
    def load(cls) -> tuple[str, str] | None:
        if cls._keyring_usable():
            try:
                username = keyring.get_password(KEYRING_SERVICE, cls.USER_KEY)
                password = keyring.get_password(KEYRING_SERVICE, cls.PASSWORD_KEY)
                if username and password:
                    return username, password
            except Exception:
                pass
        if not CREDENTIAL_FILE.exists():
            return None
        try:
            decrypted = cls._fallback_fernet().decrypt(CREDENTIAL_FILE.read_bytes())
            data = json.loads(decrypted.decode("utf-8"))
            username = str(data.get("username") or "").strip()
            password = str(data.get("password") or "")
            return (username, password) if username and password else None
        except (OSError, InvalidToken, ValueError, json.JSONDecodeError):
            return None

    @classmethod
    def delete(cls) -> None:
        if cls._keyring_usable():
            for key_name in (cls.USER_KEY, cls.PASSWORD_KEY):
                try:
                    keyring.delete_password(KEYRING_SERVICE, key_name)
                except Exception:
                    pass
        CREDENTIAL_FILE.unlink(missing_ok=True)

    @classmethod
    def status(cls) -> str:
        if not cls.load():
            return "nincs mentett Lidl-fiók"
        if cls._keyring_usable():
            try:
                if keyring.get_password(KEYRING_SERVICE, cls.USER_KEY):
                    return "mentve a Linux rendszerkulcstartóban"
            except Exception:
                pass
        return "mentve titkosított helyi fájlban"


def save_credentials_interactive() -> bool:
    print("\nLidl-fiók mentése")
    print("A jelszó nem kerül bele magába a .sh fájlba.")
    existing = CredentialStore.load()
    default_user = existing[0] if existing else ""
    prompt = f"Lidl e-mail [{default_user}]: " if default_user else "Lidl e-mail: "
    username = input(prompt).strip() or default_user
    password = getpass.getpass("Lidl jelszó: ")
    if not username or not password:
        print("Megszakítva: hiányzó felhasználónév vagy jelszó.")
        return False
    backend = CredentialStore.save(username, password)
    print(f"A hitelesítési adatok elmentve: {backend}.")
    return True


def delete_credentials_interactive() -> None:
    CredentialStore.delete()
    print("A mentett Lidl-felhasználónév és jelszó törölve.")


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


@dataclass
class BrowserSession:
    playwright: Playwright
    context: BrowserContext
    page: Page
    last_request_at: float = 0.0

    @classmethod
    def open(cls, playwright: Playwright, headless: bool) -> "BrowserSession":
        kwargs: dict[str, Any] = {
            "user_data_dir": str(PROFILE_DIR),
            "headless": headless,
            "locale": "hu-HU",
            "viewport": {"width": 1280, "height": 900},
            "slow_mo": 0 if headless else 120,
            "firefox_user_prefs": {
                "browser.sessionstore.resume_from_crash": False,
                "browser.tabs.warnOnClose": False,
                "dom.webnotifications.enabled": False,
            },
        }
        context = playwright.firefox.launch_persistent_context(**kwargs)
        page = context.pages[0] if context.pages else context.new_page()
        page.set_default_timeout(45_000)
        return cls(playwright, context, page)

    def close(self) -> None:
        self.context.close()

    def goto_home(self) -> None:
        self.page.goto(HOME_URL, wait_until="domcontentloaded", timeout=90_000)

    def _pace(self) -> None:
        elapsed = time.monotonic() - self.last_request_at
        wait_for = REQUEST_DELAY_SECONDS - elapsed
        if wait_for > 0:
            time.sleep(wait_for)

    def _fetch_json_once(self, url: str) -> tuple[int, Any, str, str]:
        self._pace()
        result = self.page.evaluate(
            """
            async (url) => {
                try {
                    const response = await fetch(url, {
                        method: 'GET',
                        credentials: 'include',
                        headers: {Accept: 'application/json'}
                    });
                    const text = await response.text();
                    let data = null;
                    try { data = JSON.parse(text); } catch (_) {}
                    return {
                        status: response.status,
                        data,
                        text,
                        finalUrl: response.url,
                        retryAfter: response.headers.get('Retry-After') || ''
                    };
                } catch (error) {
                    return {status: 0, data: null, text: String(error), finalUrl: '', retryAfter: ''};
                }
            }
            """,
            url,
        )
        self.last_request_at = time.monotonic()
        return (
            int(result["status"]),
            result.get("data"),
            str(result.get("text", "")),
            str(result.get("retryAfter", "")),
        )

    def fetch_json(self, url: str) -> tuple[int, Any, str]:
        retryable = {0, 429, 500, 502, 503, 504}
        last_status = 0
        last_data: Any = None
        last_text = ""
        for attempt in range(MAX_REQUEST_RETRIES + 1):
            status, data, text, retry_after = self._fetch_json_once(url)
            last_status, last_data, last_text = status, data, text
            if status not in retryable:
                return status, data, text
            if attempt >= MAX_REQUEST_RETRIES:
                break
            try:
                delay = float(retry_after) if retry_after else min(30.0, 2.0 ** attempt)
            except ValueError:
                delay = min(30.0, 2.0 ** attempt)
            print(f"API átmeneti hiba (HTTP {status}); újrapróbálás {delay:.0f} mp múlva…", flush=True)
            time.sleep(max(1.0, delay))
        return last_status, last_data, last_text

    def fetch_json_batch(self, urls: list[str]) -> list[dict[str, Any]]:
        # Szándékosan soros: kevésbé terheli a Lidl API-ját, és kisebb a 429/503 esélye.
        results: list[dict[str, Any]] = []
        for url in urls:
            status, data, text = self.fetch_json(url)
            results.append({"url": url, "status": status, "data": data, "text": text})
        return results

    def authenticated(self) -> bool:
        """Gyors munkamenet-ellenőrzés.

        Szándékosan nincs 1/2/4/8 mp-es API retry: ha a meglévő profilból az
        első kérés nem használható, rögtön az autologin következik.
        """
        try:
            self.goto_home()
            status, data, _, _ = self._fetch_json_once(API_LIST.format(page=1))
            return status == 200 and isinstance(data, dict) and isinstance(data.get("items"), list)
        except Exception:
            return False


class AuthTemporarilyUnavailable(RuntimeError):
    pass


def _read_auth_state() -> dict[str, Any]:
    try:
        data = json.loads(AUTH_STATE_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError, json.JSONDecodeError):
        return {}


def _write_auth_state(data: dict[str, Any]) -> None:
    AUTH_STATE_FILE.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    os.chmod(AUTH_STATE_FILE, 0o600)


def auth_cooldown_remaining() -> int:
    state = _read_auth_state()
    until = float(state.get("cooldown_until") or 0)
    return max(0, int(until - time.time()))


def mark_auth_failure(reason: str, seconds: int = AUTH_COOLDOWN_SECONDS) -> None:
    _write_auth_state({
        "cooldown_until": time.time() + seconds,
        "reason": reason,
        "failed_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    })


def clear_auth_failure() -> None:
    AUTH_STATE_FILE.unlink(missing_ok=True)


def page_reports_auth_overload(page: Page) -> bool:
    phrases = (
        "túlterheltek vagyunk",
        "kerjük, várj néhány percet",
        "próbáld meg újra",
        "too many requests",
        "try again later",
        "temporarily unavailable",
    )
    for frame in page.frames:
        try:
            body = normalize(frame.locator("body").inner_text(timeout=1500))
        except Exception:
            continue
        if any(normalize(phrase) in body for phrase in phrases):
            return True
    return False


def _first_visible(page: Page, selectors: list[str], timeout_ms: int = 12_000) -> Any | None:
    deadline = time.monotonic() + timeout_ms / 1000
    while time.monotonic() < deadline:
        for frame in page.frames:
            for selector in selectors:
                try:
                    locator = frame.locator(selector).first
                    if locator.count() and locator.is_visible():
                        return locator
                except Exception:
                    continue
        page.wait_for_timeout(250)
    return None


def _click_first_visible(page: Page, selectors: list[str], timeout_ms: int = 5_000) -> bool:
    locator = _first_visible(page, selectors, timeout_ms)
    if locator is None:
        return False
    try:
        locator.click()
        return True
    except Exception:
        return False


def try_saved_credentials_login(session: BrowserSession, username: str, password: str) -> bool:
    page = session.page
    session.goto_home()
    page.wait_for_timeout(1500)
    if page_reports_auth_overload(page):
        raise AuthTemporarilyUnavailable("A Lidl belépési szolgáltatása átmenetileg korlátoz.")

    _click_first_visible(page, [
        "#onetrust-accept-btn-handler",
        "button:has-text('Összes elfogadása')",
        "button:has-text('Elfogadom')",
        "button:has-text('Accept all')",
    ], timeout_ms=1800)

    email_selectors = [
        "input[autocomplete='username']", "input[type='email']",
        "input[name='email']", "input[name='Email']", "input[name='username']",
        "input[id*='email' i]", "input[id*='user' i]",
    ]
    password_selectors = [
        "input[autocomplete='current-password']", "input[type='password']",
        "input[name='password']", "input[name='Password']", "input[id*='password' i]",
    ]
    submit_selectors = [
        "button[type='submit']", "input[type='submit']",
        "button:has-text('Bejelentkezés')", "button:has-text('Belépés')",
        "button:has-text('Tovább')", "button:has-text('Folytatás')",
        "button:has-text('Continue')", "button:has-text('Sign in')", "button:has-text('Log in')",
    ]

    email = _first_visible(page, email_selectors, timeout_ms=20_000)
    if email is None:
        if page_reports_auth_overload(page):
            raise AuthTemporarilyUnavailable("A Lidl belépési szolgáltatása átmenetileg korlátoz.")
        return False
    email.fill(username)
    page.wait_for_timeout(900)

    password_field = _first_visible(page, password_selectors, timeout_ms=1200)
    if password_field is None:
        if not _click_first_visible(page, submit_selectors, timeout_ms=5000):
            return False
        page.wait_for_timeout(2400)
        if page_reports_auth_overload(page):
            raise AuthTemporarilyUnavailable("A Lidl túl sok belépési kísérlet miatt várakozást kér.")
        password_field = _first_visible(page, password_selectors, timeout_ms=20_000)
    if password_field is None:
        return False

    password_field.fill(password)
    page.wait_for_timeout(1100)
    if not _click_first_visible(page, submit_selectors, timeout_ms=5000):
        try:
            password_field.press("Enter")
        except Exception:
            return False

    try:
        page.wait_for_url(re.compile(r"^https://www\.lidl\.hu/.*"), timeout=45_000)
    except Exception:
        if page_reports_auth_overload(page):
            raise AuthTemporarilyUnavailable("A Lidl belépési szolgáltatása átmenetileg korlátoz.")
        return False

    try:
        session.goto_home()
        status, data, _, _ = session._fetch_json_once(API_LIST.format(page=1))
        ok = status == 200 and isinstance(data, dict) and isinstance(data.get("items"), list)
        if ok:
            clear_auth_failure()
        return ok
    except Exception:
        return False

def login_with_playwright(playwright: Playwright, unattended: bool = False) -> bool:
    credentials = CredentialStore.load()
    if credentials is None:
        if unattended:
            print("Nincs mentett Lidl-fiók. Mentsd el egyszer a c paranccsal vagy a --save-credentials kapcsolóval.")
            return False
        answer = input("\nNincs mentett Lidl-fiók. Elmented most a felhasználónevet és jelszót? [I/n] ").strip().lower()
        if answer not in ("n", "nem", "no"):
            save_credentials_interactive()
            credentials = CredentialStore.load()

    # A V2.4 nem használ 10/30 perces autologin-cooldownt. Egy frissítés során
    # legfeljebb két egymást követő automatikus próbát tesz, köztük rövid várakozással.
    clear_auth_failure()

    print("\nMegnyitom a Lidl belépést egy külön, tartós Firefox-profilban.")
    session = BrowserSession.open(playwright, headless=False)
    try:
        if credentials is not None:
            username, password = credentials
            last_error = "Az automatikus belépés nem sikerült."
            for attempt in range(1, AUTOLOGIN_ATTEMPTS + 1):
                print(f"Automatikus belépési próbálkozás {attempt}/{AUTOLOGIN_ATTEMPTS}…")
                try:
                    if try_saved_credentials_login(session, username, password):
                        print("Automatikus belépés sikerült. A munkamenet megmarad.")
                        return True
                    last_error = "A belépési folyamat nem fejeződött be sikeresen."
                except AuthTemporarilyUnavailable as error:
                    last_error = str(error)
                    print(last_error)

                if attempt < AUTOLOGIN_ATTEMPTS:
                    print(f"Várok {AUTOLOGIN_RETRY_DELAY_SECONDS} másodpercet, majd egyszer újrapróbálom…")
                    page = session.page
                    try:
                        page.wait_for_timeout(AUTOLOGIN_RETRY_DELAY_SECONDS * 1000)
                        page.goto(HOME_URL, wait_until="domcontentloaded", timeout=90_000)
                        page.wait_for_timeout(1500)
                    except Exception:
                        time.sleep(AUTOLOGIN_RETRY_DELAY_SECONDS)

            print(f"Mindkét automatikus belépési próbálkozás sikertelen. Utolsó hiba: {last_error}")
            if unattended:
                return False
            print("Ha CAPTCHA vagy további ellenőrzés látszik, fejezd be kézzel a böngészőben.")
        else:
            session.goto_home()
            print("Jelentkezz be kézzel a megnyíló böngészőablakban.")

        while True:
            input("\nSikeres belépés után térj vissza ide, és nyomj ENTER-t… ")
            session.goto_home()
            status, data, text, _ = session._fetch_json_once(API_LIST.format(page=1))
            if status == 200 and isinstance(data, dict) and isinstance(data.get("items"), list):
                clear_auth_failure()
                print("Belépés rendben. A munkamenet megmarad a következő indításokra.")
                return True
            print(f"Még nem látom a bejelentkezett munkamenetet (HTTP {status}). Próbáld újra.")
            if text and status not in (0, 200):
                print(text[:200])
    finally:
        session.close()

def login_interactive() -> bool:
    with sync_playwright() as playwright:
        return login_with_playwright(playwright, unattended=False)


def open_online(receipt_id: str) -> None:
    with sync_playwright() as playwright:
        session = BrowserSession.open(playwright, headless=False)
        try:
            session.page.goto(DETAIL_URL.format(receipt_id=receipt_id), wait_until="domcontentloaded")
            input("A blokk megnyílt. Bezáráshoz térj vissza ide, és nyomj ENTER-t… ")
        finally:
            session.close()


def ensure_authenticated_session(playwright: Playwright) -> BrowserSession:
    session = BrowserSession.open(playwright, headless=True)
    if session.authenticated():
        return session
    session.close()
    print("A Lidl-munkamenet hiányzik vagy lejárt.")
    if not login_with_playwright(playwright, unattended=True):
        raise RuntimeError("Az automatikus belépés két próbálkozás után sem sikerült")
    session = BrowserSession.open(playwright, headless=True)
    if not session.authenticated():
        session.close()
        raise RuntimeError("A munkamenet a belépés után sem használható")
    return session


def chunks(values: list[Any], size: int) -> Iterable[list[Any]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


def sync_index(database: Database, full: bool = False) -> None:
    print("\nLidl indexfrissítés")
    print("=" * 60)
    with sync_playwright() as playwright:
        session = ensure_authenticated_session(playwright)
        try:
            status, first, text = session.fetch_json(API_LIST.format(page=1))
            if status != 200 or not isinstance(first, dict):
                raise RuntimeError(f"A blokklista nem tölthető le (HTTP {status}): {text[:200]}")

            page_size = int(first.get("size") or 10)
            total_count = int(first.get("totalCount") or len(first.get("items") or []))
            total_pages = max(1, (total_count + page_size - 1) // page_size)
            full_required = full or database.get_meta("full_sync_complete", "0") != "1"
            known = database.all_receipt_ids()
            tickets: list[dict[str, Any]] = []

            if full_required:
                print(f"Teljes blokklista: {total_count} blokk, {total_pages} oldal.")
                tickets.extend(first.get("items") or [])
                pages = list(range(2, total_pages + 1))
                completed = 1
                for page_batch in chunks(pages, 5):
                    urls = [API_LIST.format(page=page) for page in page_batch]
                    results = session.fetch_json_batch(urls)
                    for page_no, result in zip(page_batch, results):
                        if result.get("status") != 200 or not isinstance(result.get("data"), dict):
                            raise RuntimeError(
                                f"A(z) {page_no}. listaoldal hibás (HTTP {result.get('status')})"
                            )
                        tickets.extend(result["data"].get("items") or [])
                        completed += 1
                    print(f"Blokklista: {completed}/{total_pages} oldal", flush=True)
                database.upsert_metadata(tickets)
                database.set_meta("full_sync_complete", "1")
            else:
                print("Inkrementális frissítés: csak az új blokkok keresése.")
                page_no = 1
                while page_no <= total_pages:
                    if page_no == 1:
                        page_data = first
                    else:
                        status, page_data, text = session.fetch_json(API_LIST.format(page=page_no))
                        if status != 200 or not isinstance(page_data, dict):
                            raise RuntimeError(
                                f"A(z) {page_no}. listaoldal hibás (HTTP {status}): {text[:120]}"
                            )
                    page_items = page_data.get("items") or []
                    unknown = [ticket for ticket in page_items if str(ticket.get("id")) not in known]
                    tickets.extend(unknown)
                    print(
                        f"Listaoldal {page_no}: {len(unknown)} új blokk",
                        flush=True,
                    )
                    if not unknown:
                        break
                    database.upsert_metadata(unknown)
                    known.update(str(ticket.get("id")) for ticket in unknown)
                    page_no += 1

            # A korábbi sikertelen blokkokat is újrapróbáljuk.
            pending = [dict(row) for row in database.pending_rows()]
            if not pending:
                database.set_meta("last_refresh", dt.datetime.now().astimezone().isoformat(timespec="seconds"))
                stats = database.stats()
                print(f"Nincs feldolgozatlan új blokk. Index: {stats['receipts']} blokk, {stats['items']} tétel.")
                return

            print(f"Feldolgozandó blokk: {len(pending)}")
            processed = 0
            failures = 0
            item_total = 0
            for pending_batch in chunks(pending, CONCURRENCY):
                urls = [API_DETAIL.format(receipt_id=ticket["id"]) for ticket in pending_batch]
                results = session.fetch_json_batch(urls)
                for ticket, result in zip(pending_batch, results):
                    processed += 1
                    try:
                        if result.get("status") != 200 or not isinstance(result.get("data"), dict):
                            raise RuntimeError(f"HTTP {result.get('status')}: {str(result.get('text', ''))[:120]}")
                        item_total += database.save_detail(ticket, result["data"])
                    except Exception as error:
                        failures += 1
                        print(f"  HIBÁS blokk {ticket['id']}: {error}")
                    print(
                        f"Blokkok: {processed}/{len(pending)} · hibás: {failures}",
                        end="\r",
                        flush=True,
                    )
            print()
            database.set_meta("last_refresh", dt.datetime.now().astimezone().isoformat(timespec="seconds"))
            stats = database.stats()
            print(
                f"Kész. {stats['receipts']} blokk, {stats['items']} tétel. "
                f"Most feldolgozott tétel: {item_total}. Függő blokk: {stats['pending']}."
            )
        finally:
            session.close()


def migrate_browser_engine() -> None:
    """Egyszeri V2.3 migráció: új Firefox-profil és tiszta auth-várakozási állapot."""
    marker = "firefox-playwright-v1"
    try:
        current = BROWSER_ENGINE_MARKER.read_text(encoding="utf-8").strip()
    except OSError:
        current = ""
    if current != marker:
        AUTH_STATE_FILE.unlink(missing_ok=True)
        BROWSER_ENGINE_MARKER.write_text(marker, encoding="utf-8")
        os.chmod(BROWSER_ENGINE_MARKER, 0o600)


def reset_browser_profile() -> None:
    if PROFILE_DIR.exists():
        shutil.rmtree(PROFILE_DIR)
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    print("A Lidl Firefox-munkamenet törölve. A helyi blokkindex megmaradt.")


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
                self._external_action(screen, login_interactive)
            elif key == ord("c"):
                self._external_action(screen, save_credentials_interactive)
            elif key == ord("C"):
                if self._confirm(screen, "Töröljem a mentett Lidl-felhasználónevet és jelszót?"):
                    self._external_action(screen, delete_credentials_interactive)
            elif key in (ord("o"), ord("O")) and self.results:
                receipt_id = self.results[self.selected]["receipt_id"]
                self._external_action(screen, lambda: open_online(receipt_id))
            elif key in (ord("s"), ord("S")):
                self._stats_popup(screen)
            elif key in (ord("x"), ord("X")):
                if self._confirm(screen, "Töröljem a Lidl belépési munkamenetet? A blokkindex megmarad."):
                    self._external_action(screen, reset_browser_profile)
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
        help_line = "/ keres · ↑↓ · ENTER blokk · r frissít · l blokkok · L belép · c fiók mentés · C fiók törlés · o online · s stat · x munkamenet · D index · q vége"
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
        curses.def_prog_mode()
        curses.endwin()
        try:
            action()
        except Exception as error:
            print(f"\nHIBA: {error}", file=sys.stderr)
        print("\n3 másodperc múlva visszatérek a TUI-hoz…")
        time.sleep(3)
        curses.reset_prog_mode()
        curses.curs_set(0)
        screen.clear()

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
    parser.add_argument("--login", action="store_true", help="Lidl-belépés megnyitása")
    parser.add_argument("--save-credentials", action="store_true", help="Lidl-fiók biztonságos mentése")
    parser.add_argument("--delete-credentials", action="store_true", help="Mentett Lidl-fiók törlése")
    parser.add_argument("--credential-status", action="store_true", help="Hitelesítőadat-tárolás állapota")
    parser.add_argument("--sync", action="store_true", help="Inkrementális frissítés")
    parser.add_argument("--full-sync", action="store_true", help="Teljes listaellenőrzés")
    parser.add_argument("--search", metavar="SZÖVEG", help="Nem interaktív keresés")
    parser.add_argument("--stats", action="store_true", help="Statisztika kiírása")
    parser.add_argument("--logout", action="store_true", help="Lidl-munkamenet törlése")
    parser.add_argument("--clear-index", action="store_true", help="Helyi index törlése")
    parser.add_argument("--browser-info", action="store_true", help="Használt böngészőmotor kiírása")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    migrate_browser_engine()
    database = Database()
    try:
        if args.browser_info:
            print(f"Böngészőmotor: {BROWSER_ENGINE}; profil: {PROFILE_DIR}")
            return 0
        if args.login:
            return 0 if login_interactive() else 1
        if args.save_credentials:
            return 0 if save_credentials_interactive() else 1
        if args.delete_credentials:
            delete_credentials_interactive()
            return 0
        if args.credential_status:
            print(CredentialStore.status())
            return 0
        if args.sync:
            sync_index(database, full=False)
            return 0
        if args.full_sync:
            sync_index(database, full=True)
            return 0
        if args.logout:
            reset_browser_profile()
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
            print("A TUI-hoz terminál szükséges. Használható: --sync, --search, --stats, --login, --save-credentials")
            return 2
        Tui(database).run()
        return 0
    finally:
        database.close()


if __name__ == "__main__":
    raise SystemExit(main())

__LIDL_PYTHON_APP_END__
__LIDL_PYTHON_PAYLOAD__
