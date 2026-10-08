"""Offline regression tests for Lidl blokkkereső 3.1.0 analytics."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load_app():
    shell = (ROOT / "lidl-blokkkereso.sh").read_text(encoding="utf-8")
    code = shell.split("__LIDL_PYTHON_APP_BEGIN__\n", 1)[1].split("\n__LIDL_PYTHON_APP_END__", 1)[0]
    import types
    module = types.ModuleType("lidl_v310_test")
    module.__file__ = str(ROOT / "lidl-blokkkereso.sh")
    module.__dict__["__name__"] = "lidl_v310_test"
    exec(compile(code, module.__file__, "exec"), module.__dict__)
    return module


class AnalyticsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        old = os.environ.get("XDG_DATA_HOME")
        os.environ["XDG_DATA_HOME"] = cls.tmp.name
        try:
            cls.app = load_app()
        finally:
            if old is None:
                os.environ.pop("XDG_DATA_HOME", None)
            else:
                os.environ["XDG_DATA_HOME"] = old

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def make_db(self):
        path = Path(self.tmp.name) / f"test-{self.id().split('.')[-1]}.sqlite3"
        if path.exists():
            path.unlink()
        return self.app.Database(path)

    def seed(self, db):
        app = self.app
        today = app.dt.datetime.now().astimezone().date()
        current = today.replace(day=max(1, min(today.day, 20))).isoformat() + "T12:00:00+02:00"
        current2 = today.replace(day=max(1, min(today.day, 10))).isoformat() + "T12:00:00+02:00"
        prev_date = (today.replace(day=1) - app.dt.timedelta(days=1)).replace(day=15)
        previous = prev_date.isoformat() + "T12:00:00+02:00"
        with db.connection:
            db.connection.executemany(
                "INSERT INTO receipts(id,receipt_date,total_amount,articles_count,store,indexed_ok) VALUES(?,?,?,?,?,1)",
                [
                    ("r1", current, 10000, 2, "Lidl Alfa"),
                    ("r2", current2, 5000, 1, "Lidl Alfa"),
                    ("r3", previous, 8000, 1, "Lidl Beta"),
                ],
            )
            db.connection.executemany(
                "INSERT INTO items(receipt_id,line_no,article_id,description,normalized,quantity,unit_price,item_total,tax_type,receipt_date,store) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                [
                    ("r1", 1, "A1", "Tej & <teszt>", "tej teszt", 2, 1000, 2000, "A", current, "Lidl Alfa"),
                    ("r1", 2, "A2", "Kenyér", "kenyer", 1, 1500, 1500, "A", current, "Lidl Alfa"),
                    ("r2", 1, "A1", "Tej & <teszt>", "tej teszt", 1, 1000, 1000, "A", current2, "Lidl Alfa"),
                    ("r3", 1, "A3", "Sajt", "sajt", 1, 2500, 2500, "A", previous, "Lidl Beta"),
                ],
            )

    def test_stats_money_aggregates(self):
        db = self.make_db()
        self.seed(db)
        try:
            stats = db.stats()
            self.assertEqual(stats["receipts"], 3)
            self.assertEqual(stats["spend_total"], 23000.0)
            self.assertEqual(stats["current_month_spend"], 15000.0)
            self.assertEqual(stats["previous_month_spend"], 8000.0)
            self.assertAlmostEqual(stats["average_receipt"], 23000 / 3)
            self.assertAlmostEqual(stats["month_change_pct"], 87.5)
        finally:
            db.close()

    def test_monthly_daily_top_and_store_analytics(self):
        db = self.make_db()
        self.seed(db)
        try:
            months = db.monthly_spend(12)
            self.assertEqual(len(months), 12)
            self.assertEqual(months[-1]["total"], 15000.0)
            self.assertEqual(len(db.daily_spend(30)), 30)
            self.assertEqual(db.top_receipts(1)[0]["id"], "r1")
            self.assertEqual(db.top_products(1)[0]["description"], "Tej & <teszt>")
            self.assertEqual(db.top_products(1)[0]["receipt_count"], 2)
            self.assertEqual(db.store_stats(1)[0]["store_name"], "Lidl Alfa")
            self.assertEqual(db.store_stats(1)[0]["spend"], 15000.0)
        finally:
            db.close()

    def test_sparkline_and_bar(self):
        app = self.app
        self.assertEqual(len(app.sparkline([0, 1, 2, 3], 4)), 4)
        self.assertEqual(app.bar_text(5, 10, 10), "█████")
        self.assertEqual(app.percent_text(12.34), "+12,3%")
        self.assertEqual(app.percent_text(None), "–")

    def test_html_report_is_local_and_escaped(self):
        db = self.make_db()
        self.seed(db)
        try:
            out = Path(self.tmp.name) / "report.html"
            result = self.app.generate_html_report(db, out)
            report = result.read_text(encoding="utf-8")
            self.assertEqual(result, out)
            self.assertIn("Lidl költési analitika", report)
            self.assertIn("Top 20 leggyakoribb termék", report)
            self.assertIn("Tej &amp; &lt;teszt&gt;", report)
            self.assertNotIn("https://cdn", report)
            self.assertNotIn("<script", report.lower())
        finally:
            db.close()

    def test_version_is_310(self):
        p = subprocess.run(
            ["bash", str(ROOT / "lidl-blokkkereso.sh"), "--version"],
            capture_output=True,
            text=True,
            timeout=8,
        )
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("3.1.0", p.stdout)


class ReleaseTests(unittest.TestCase):
    def test_release_builder_preserves_signed_xpi_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            td = Path(d)
            source = td / "source"
            shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns("*.zip", "*.xpi", "SHA256SUMS", ".git"))
            xpi = td / "signed-test.xpi"
            with zipfile.ZipFile(xpi, "w") as z:
                for rel in ("manifest.json", "background.js", "content.js"):
                    z.write(source / "extension" / rel, rel)
                z.writestr("META-INF/mozilla.rsa", "OFFLINE TEST MARKER ONLY")
            old = td / "lidl-blokkkereso-v3.0.2-linux.zip"
            with zipfile.ZipFile(old, "w") as z:
                z.write(xpi, "lidl-blokkkereso-v3.0.2/lidl-blokkkereso-v3-signed.xpi")
            sums = td / "old-SHA256SUMS"
            sums.write_text(f"{hashlib.sha256(old.read_bytes()).hexdigest()}  {old.name}\n")
            out = td / "out"
            env = {
                **os.environ,
                "LIDL_V310_TEST_OLD_RELEASE_ZIP": str(old),
                "LIDL_V310_TEST_OLD_SUMS": str(sums),
                "LIDL_V310_TEST_ALLOW_UNSIGNED_FIXTURE": "1",
            }
            p = subprocess.run(
                ["bash", str(source / "scripts/build-release-v3.1.0.sh"), str(out)],
                env=env,
                capture_output=True,
                text=True,
                timeout=20,
            )
            self.assertEqual(p.returncode, 0, p.stdout + "\n" + p.stderr)
            archive = out / "lidl-blokkkereso-v3.1.0-linux.zip"
            self.assertTrue(archive.exists())
            with zipfile.ZipFile(archive) as z:
                self.assertEqual(
                    z.read("lidl-blokkkereso-v3.1.0/lidl-blokkkereso-v3-signed.xpi"),
                    xpi.read_bytes(),
                )
            self.assertEqual(
                (out / "lidl-blokkkereso-v3-3.0.0-signed.xpi").read_bytes(),
                xpi.read_bytes(),
            )


if __name__ == "__main__":
    unittest.main()
