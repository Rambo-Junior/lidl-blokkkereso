# Offline regression tests for Lidl blokkkereső 3.0.2.
from __future__ import annotations
import contextlib, hashlib, io, os, shutil, subprocess, tempfile, unittest, zipfile
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]

def load_embedded_app():
    shell = (ROOT / "lidl-blokkkereso.sh").read_text(encoding="utf-8")
    script = shell.split("__LIDL_PYTHON_APP_BEGIN__\n", 1)[1].split("\n__LIDL_PYTHON_APP_END__", 1)[0]
    import types
    module = types.ModuleType("lidl_app_v302_test")
    module.__file__ = str(ROOT / "lidl-blokkkereso.sh")
    module.__dict__["__name__"] = "lidl_app_v302_test"
    exec(compile(script, module.__file__, "exec"), module.__dict__)
    return module

class Clock:
    def __init__(self): self.t = 0.0
    def monotonic(self): return self.t
    def sleep(self, delta): self.t += delta

class RetryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        old = os.environ.get("XDG_DATA_HOME")
        os.environ["XDG_DATA_HOME"] = cls.tmp.name
        try: cls.app = load_embedded_app()
        finally:
            if old is None: del os.environ["XDG_DATA_HOME"]
            else: os.environ["XDG_DATA_HOME"] = old
    @classmethod
    def tearDownClass(cls): cls.tmp.cleanup()

    def test_startup_timeout_is_retryable_subclass(self):
        app = self.app; clock = Clock()
        with mock.patch.object(app, "_read_run_status", return_value=None), mock.patch.object(app.time, "monotonic", clock.monotonic), mock.patch.object(app.time, "sleep", clock.sleep), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(app.BrowserBridgeNoResponseError): app._wait_for_v3_run("retryable-timeout", 600)

    def test_trigger_retries_once_with_new_run_id(self):
        app = self.app; runs = Path(self.tmp.name) / "retry-runs"
        with mock.patch.object(app, "V3_RUNS_DIR", runs), mock.patch.object(app, "V3_STARTUP_RETRIES", 1), mock.patch.object(app, "_new_run_id", side_effect=["sync-first", "sync-second"]), mock.patch.object(app, "open_in_normal_firefox") as opener, mock.patch.object(app, "_wait_for_v3_run", side_effect=[app.BrowserBridgeNoResponseError("nincs válasz"), {"state":"done","phase":"done"}]), mock.patch.object(app.time, "sleep"), contextlib.redirect_stdout(io.StringIO()) as output:
            run_id, run_dir, status = app._start_v3_run("sync", 600, mode="incremental")
        self.assertEqual(run_id, "sync-second"); self.assertEqual(run_dir, runs / "sync-second"); self.assertEqual(status["state"], "done"); self.assertEqual(opener.call_count, 2)
        self.assertIn("lbk_v3_run=sync-first", opener.call_args_list[0].args[0]); self.assertIn("lbk_v3_run=sync-second", opener.call_args_list[1].args[0]); self.assertIn("Automatikus újrapróbálás 1/1", output.getvalue())

    def test_nonstartup_bridge_error_is_not_retried(self):
        app = self.app; runs = Path(self.tmp.name) / "nonstartup-runs"
        with mock.patch.object(app, "V3_RUNS_DIR", runs), mock.patch.object(app, "V3_STARTUP_RETRIES", 1), mock.patch.object(app, "_new_run_id", return_value="sync-error"), mock.patch.object(app, "open_in_normal_firefox") as opener, mock.patch.object(app, "_wait_for_v3_run", side_effect=app.BrowserBridgeError("API/bridge hiba")):
            with self.assertRaisesRegex(app.BrowserBridgeError, "API/bridge"): app._start_v3_run("sync", 600, mode="incremental")
        opener.assert_called_once()

    def test_retry_can_be_disabled(self):
        app = self.app; runs = Path(self.tmp.name) / "disabled-runs"
        with mock.patch.object(app, "V3_RUNS_DIR", runs), mock.patch.object(app, "V3_STARTUP_RETRIES", 0), mock.patch.object(app, "_new_run_id", return_value="sync-no-retry"), mock.patch.object(app, "open_in_normal_firefox") as opener, mock.patch.object(app, "_wait_for_v3_run", side_effect=app.BrowserBridgeNoResponseError("nincs válasz")):
            with self.assertRaises(app.BrowserBridgeNoResponseError): app._start_v3_run("sync", 600, mode="incremental")
        opener.assert_called_once()

class ReleaseTests(unittest.TestCase):
    def test_version_is_302(self):
        p=subprocess.run(["bash",str(ROOT/"lidl-blokkkereso.sh"),"--version"],capture_output=True,text=True,timeout=8)
        self.assertEqual(p.returncode,0,p.stderr); self.assertIn("3.0.2",p.stdout)
    def test_python_payload_compiles(self):
        shell=(ROOT/"lidl-blokkkereso.sh").read_text(encoding="utf-8"); script=shell.split("__LIDL_PYTHON_APP_BEGIN__\n",1)[1].split("\n__LIDL_PYTHON_APP_END__",1)[0]; compile(script,str(ROOT/"lidl-blokkkereso.sh"),"exec")
    def test_v302_release_builder_preserves_xpi_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            td=Path(d); source=td/"source"; shutil.copytree(ROOT,source,ignore=shutil.ignore_patterns("*.zip","*.xpi","SHA256SUMS",".git"))
            xpi=td/"signed-test.xpi"
            with zipfile.ZipFile(xpi,"w") as z:
                for rel in ("manifest.json","background.js","content.js"): z.write(source/"extension"/rel,rel)
                z.writestr("META-INF/mozilla.rsa","OFFLINE TEST MARKER ONLY")
            old=td/"lidl-blokkkereso-v3.0.1-linux.zip"
            with zipfile.ZipFile(old,"w") as z: z.write(xpi,"lidl-blokkkereso-v3.0.1/lidl-blokkkereso-v3-signed.xpi")
            sums=td/"old-SHA256SUMS"; sums.write_text(f"{hashlib.sha256(old.read_bytes()).hexdigest()}  {old.name}\n")
            out=td/"out"; env={**os.environ,"LIDL_V302_TEST_OLD_RELEASE_ZIP":str(old),"LIDL_V302_TEST_OLD_SUMS":str(sums),"LIDL_V302_TEST_ALLOW_UNSIGNED_FIXTURE":"1"}
            p=subprocess.run(["bash",str(source/"scripts/build-release-v3.0.2.sh"),str(out)],env=env,capture_output=True,text=True,timeout=20)
            self.assertEqual(p.returncode,0,p.stdout+"\n"+p.stderr)
            archive=out/"lidl-blokkkereso-v3.0.2-linux.zip"; self.assertTrue(archive.exists())
            with zipfile.ZipFile(archive) as z: preserved=z.read("lidl-blokkkereso-v3.0.2/lidl-blokkkereso-v3-signed.xpi")
            self.assertEqual(preserved,xpi.read_bytes()); self.assertEqual((out/"lidl-blokkkereso-v3-3.0.0-signed.xpi").read_bytes(),xpi.read_bytes())

if __name__ == "__main__": unittest.main()
