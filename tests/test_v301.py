"""Offline regression tests for Lidl blokkkereső 3.0.1 (no Lidl credentials)."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load_embedded_app():
    shell = (ROOT / 'lidl-blokkkereso.sh').read_text(encoding='utf8')
    script = shell.split('__LIDL_PYTHON_APP_BEGIN__\n', 1)[1].split('\n__LIDL_PYTHON_APP_END__', 1)[0]
    import types
    module = types.ModuleType('lidl_app_v301_test')
    module.__file__ = str(ROOT / 'lidl-blokkkereso.sh')
    module.__dict__['__name__'] = 'lidl_app_v301_test'
    exec(compile(script, module.__file__, 'exec'), module.__dict__)
    return module


class Clock:
    def __init__(self):
        self.t = 0.0

    def monotonic(self):
        return self.t

    def sleep(self, delta):
        self.t += delta


class BridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        old = os.environ.get('XDG_DATA_HOME')
        os.environ['XDG_DATA_HOME'] = cls.tmp.name
        try:
            cls.app = load_embedded_app()
        finally:
            if old is None:
                del os.environ['XDG_DATA_HOME']
            else:
                os.environ['XDG_DATA_HOME'] = old

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_missing_extension_fails_fast_instead_of_ten_minutes(self):
        clock = Clock()
        app = self.app
        with mock.patch.object(app, '_read_run_status', return_value=None), \
             mock.patch.object(app.time, 'monotonic', clock.monotonic), \
             mock.patch.object(app.time, 'sleep', clock.sleep), \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(app.BrowserBridgeError, r'30 másodpercen'):
                app._wait_for_v3_run('probe-test', 600)
        self.assertLess(clock.t, 32)

    def test_status_success(self):
        app = self.app
        statuses = [None, {'state':'running','phase':'list','listPage':1,'totalPages':2,'updatedAt':'x'},
                    {'state':'done','phase':'done','message':'Kész','updatedAt':'y'}]
        with mock.patch.object(app, '_read_run_status', side_effect=statuses), \
             contextlib.redirect_stdout(io.StringIO()):
            result = app._wait_for_v3_run('sync-test', 5)
        self.assertEqual(result['state'], 'done')

    def test_stalled_run_is_detected(self):
        app = self.app
        clock = Clock()
        status = {'state':'running','phase':'list','listPage':1,'updatedAt':'no-progress'}
        with mock.patch.object(app, '_read_run_status', return_value=status), \
             mock.patch.object(app.time, 'monotonic', clock.monotonic), \
             mock.patch.object(app.time, 'sleep', clock.sleep), \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(app.BrowserBridgeError, r'90 másodperce'):
                app._wait_for_v3_run('sync-stalled', 600)
        self.assertLess(clock.t, 92)

    def test_ctrl_c_restores_curses(self):
        app = self.app
        screen = mock.Mock()
        with mock.patch.object(app.curses, 'def_prog_mode') as save, \
             mock.patch.object(app.curses, 'endwin') as end, \
             mock.patch.object(app.curses, 'reset_prog_mode') as restore, \
             mock.patch.object(app.curses, 'curs_set'), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            app.Tui(None)._external_action(screen, lambda: (_ for _ in ()).throw(KeyboardInterrupt()))
        save.assert_called_once()
        end.assert_called_once()
        restore.assert_called_once()
        screen.clear.assert_called_once()
        self.assertIn('megszakítva', output.getvalue())


class IntegrationTests(unittest.TestCase):
    def test_python_payload_compiles(self):
        src = (ROOT / 'lidl-blokkkereso.sh').read_text()
        code = src.split('__LIDL_PYTHON_APP_BEGIN__\n', 1)[1].split('\n__LIDL_PYTHON_APP_END__', 1)[0]
        compile(code, str(ROOT / 'lidl-blokkkereso.sh'), 'exec')

    def test_native_host_message_in_temp_data_dir(self):
        with tempfile.TemporaryDirectory() as d:
            m = json.dumps({'action':'probe_result','runId':'test-v301','httpStatus':200,'ok':True}).encode()
            env = {**os.environ,'XDG_DATA_HOME':d}
            p = subprocess.run(['python3', str(ROOT / 'native/lidl-native-host.py')],
                               input=struct.pack('<I',len(m))+m, capture_output=True, timeout=8, env=env)
            self.assertEqual(p.returncode,0, p.stderr.decode())
            length=struct.unpack('<I',p.stdout[:4])[0]
            self.assertEqual(json.loads(p.stdout[4:4+length]), {'ok':True})
            state=json.loads((Path(d)/'lidl-blokkkereso/v3-runs/test-v301/status.json').read_text())
            self.assertEqual(state['state'],'done')

    def test_installer_xpi_survives_temp_source_deletion(self):
        with tempfile.TemporaryDirectory() as d:
            td=Path(d); home=td/'home'; home.mkdir(); src=td/'throwaway'; src.mkdir()
            for rel in ['install-v3.sh','lidl-blokkkereso.sh','native/lidl-native-host.py',
                        'extension/manifest.json','extension/background.js','extension/content.js']:
                (src/rel).parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(ROOT/rel, src/rel)
            xpi=b'FAKE-TEST-XPI-CONTENT'
            (src/'lidl-blokkkereso-v3-signed.xpi').write_bytes(xpi)
            bindir=td/'bin';bindir.mkdir()
            log=td/'firefox-log'
            firefox=bindir/'firefox'
            firefox.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$FIREFOX_TEST_LOG"\n')
            firefox.chmod(0o755)
            env={**os.environ,'HOME':str(home),'PATH':str(bindir)+':'+os.environ['PATH'],
                 'FIREFOX_TEST_LOG':str(log)}
            p=subprocess.run(['bash',str(src/'install-v3.sh')],env=env,capture_output=True,text=True,timeout=12)
            self.assertEqual(p.returncode,0,p.stderr+'\n'+p.stdout)
            persistent=home/'.local/share/lidl-blokkkereso-v3/lidl-blokkkereso-v3-signed.xpi'
            self.assertEqual(persistent.read_bytes(),xpi)
            shutil.rmtree(src)
            # Firefox is launched asynchronously; wait for its argument to appear.
            for _ in range(50):
                if log.exists() and persistent.as_uri() in log.read_text():
                    break
                time.sleep(0.02)
            self.assertTrue(log.exists())
            self.assertIn(persistent.as_uri(),log.read_text())
            manifest=json.loads((home/'.mozilla/native-messaging-hosts/hu.lidl.blokkkereso.json').read_text())
            self.assertEqual(manifest['allowed_extensions'], ['lidl-blokkkereso-v3@rambo-junior'])

    def test_installer_skips_browser_if_already_active(self):
        with tempfile.TemporaryDirectory() as d:
            home=Path(d)/'home';home.mkdir()
            prof=home/'.mozilla/firefox/abc.default-release';prof.mkdir(parents=True)
            (prof/'extensions.json').write_text(json.dumps({'addons':[{
                'id':'lidl-blokkkereso-v3@rambo-junior','active':True,
                'appDisabled':False,'userDisabled':False}]}))
            # Using the source folder without signed XPI is a valid upgrade path.
            p=subprocess.run(['bash',str(ROOT/'install-v3.sh')],env={**os.environ,'HOME':str(home)},
                             capture_output=True,text=True,timeout=12)
            self.assertEqual(p.returncode,0,p.stderr)
            self.assertIn('már telepítve és aktív',p.stdout)

    def test_release_builder_keeps_original_xpi_bytes(self):
        import hashlib
        import zipfile
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            # A valós v3.0.0 ZIP struktúráját használó OFFLINE teszt-fixture.
            source = root / 'source'
            shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns('*.zip', '*.xpi', 'SHA256SUMS'))
            for doc in ('LICENSE', 'PRIVACY.md', 'SECURITY.md'):
                (source/doc).write_text('OFFLINE TEST DOC')
            xpi = root/'signed-test.xpi'
            with zipfile.ZipFile(xpi, 'w') as z:
                for rel in ('manifest.json','background.js','content.js'):
                    z.write(source/'extension'/rel, rel)
                z.writestr('META-INF/mozilla.rsa', 'OFFLINE TEST MARKER ONLY')
            old = root/'lidl-blokkkereso-v3.0.0-linux.zip'
            with zipfile.ZipFile(old, 'w') as z:
                z.write(xpi, 'lidl-blokkkereso-v3.0.0/lidl-blokkkereso-v3-signed.xpi')
            sums = root/'old-SHA256SUMS'
            sums.write_text(f'{hashlib.sha256(old.read_bytes()).hexdigest()}  {old.name}\n')
            out = root/'out'
            env = {**os.environ, 'LIDL_V301_TEST_OLD_RELEASE_ZIP': str(old),
                   'LIDL_V301_TEST_OLD_SUMS': str(sums),
                   'LIDL_V301_TEST_ALLOW_UNSIGNED_FIXTURE': '1'}
            p = subprocess.run(['bash', str(source/'scripts/build-release-v3.0.1.sh'), str(out)],
                               env=env, capture_output=True, text=True, timeout=20)
            self.assertEqual(p.returncode, 0, p.stdout+'\n'+p.stderr)
            archive=out/'lidl-blokkkereso-v3.0.1-linux.zip'
            self.assertTrue(archive.exists())
            with zipfile.ZipFile(archive) as z:
                preserved=z.read('lidl-blokkkereso-v3.0.1/lidl-blokkkereso-v3-signed.xpi')
                self.assertEqual(preserved,xpi.read_bytes())
            self.assertEqual((out/'lidl-blokkkereso-v3-3.0.0-signed.xpi').read_bytes(),xpi.read_bytes())


if __name__=='__main__':
    unittest.main()
