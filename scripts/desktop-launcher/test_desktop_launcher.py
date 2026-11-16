import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('launcher', Path(__file__).resolve().parent.parent / 'desktop_launcher.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

DEVICE = 'F9519F65-CFEC-4924-B431-28F299116816'
SDK = Path('/fixture/papigiras-tools/flutter')
COMMAND = f'{SDK}/bin/cache/dart-sdk/bin/dartvm {SDK}/bin/cache/flutter_tools.snapshot run --no-pub -d {DEVICE}'


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pg004-test-')
        self.lock_path = Path(self.temp.name) / 'private-lock'
        self.addCleanup(self.temp.cleanup)

    def test_exact_flutter_identity_and_device(self):
        lines = [
            '123 ' + COMMAND,
            '124 ' + COMMAND.replace(' run ', ' test '),
            '125 ' + COMMAND.replace(DEVICE, 'another-device'),
            '126 ' + COMMAND.replace('/fixture/', '/other/'),
            '127 /bin/echo ' + COMMAND,
            '128 ' + COMMAND + ' -d second-device',
        ]
        self.assertEqual(launcher.flutter_pid_candidates('\n'.join(lines), SDK, DEVICE), [123])

    def test_reuse_requires_matching_working_directory(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'))
        app.sdk, app.device = SDK, DEVICE
        outputs = [Mock(stdout='123 ' + COMMAND), Mock(stdout='p123\nfcwd\nn/other/project\n')]
        with patch.object(launcher.subprocess, 'run', side_effect=outputs):
            self.assertIsNone(app.find_existing())
        outputs = [Mock(stdout='123 ' + COMMAND), Mock(stdout='p123\nfcwd\nn/fixture/Papigiras-LAB\n')]
        with patch.object(launcher.subprocess, 'run', side_effect=outputs):
            self.assertEqual(app.find_existing(), 123)

    def test_active_session_reused_without_spawn(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'), self.lock_path)
        with patch.object(app, 'validate'), patch.object(app, 'find_existing', return_value=123), patch.object(app, 'foreground') as foreground, patch.object(app, 'spawn') as spawn, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(app.start(), 0)
            foreground.assert_called_once()
            spawn.assert_not_called()

    def test_second_launch_while_locked_never_spawns(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'), self.lock_path)
        with launcher.LaunchLock(self.lock_path) as first:
            self.assertTrue(first.acquired)
            with patch.object(app, 'validate'), patch.object(app, 'find_existing', return_value=None) as find, patch.object(app, 'foreground') as foreground, patch.object(app, 'spawn') as spawn, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(app.start(), 0)
                foreground.assert_not_called()
                find.assert_called_once()
                spawn.assert_not_called()

    def test_locked_with_active_flutter_only_foregrounds_existing(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'), self.lock_path)
        with launcher.LaunchLock(self.lock_path):
            with patch.object(app, 'validate'), patch.object(app, 'find_existing', return_value=123), patch.object(app, 'foreground') as foreground, patch.object(app, 'spawn') as spawn, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(app.start(), 0)
                foreground.assert_called_once()
                spawn.assert_not_called()

    def test_inherited_lock_survives_parent_close_and_releases_with_child(self):
        with launcher.LaunchLock(self.lock_path) as parent:
            child = subprocess.Popen(
                [sys.executable, '-c', 'import sys; print("ready",flush=True); sys.stdin.read()'],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                pass_fds=(parent.fd,), text=True,
            )
            self.addCleanup(lambda: child.poll() is None and child.kill())
            self.assertEqual(child.stdout.readline().strip(), 'ready')
        with launcher.LaunchLock(self.lock_path) as contender:
            self.assertFalse(contender.acquired)
        child.communicate(timeout=5)
        with launcher.LaunchLock(self.lock_path) as released:
            self.assertTrue(released.acquired)

    def test_symlink_directory_and_lock_rejected(self):
        target = Path(self.temp.name) / 'target'
        target.mkdir(mode=0o700)
        self.lock_path.symlink_to(target)
        with self.assertRaises(launcher.LaunchError):
            with launcher.LaunchLock(self.lock_path):
                pass
        self.lock_path.unlink()
        self.lock_path.mkdir(mode=0o700)
        (self.lock_path/'launch.lock').symlink_to(target/'other')
        with self.assertRaises(OSError):
            with launcher.LaunchLock(self.lock_path):
                pass

    def test_foreground_exact_device_without_new_instance(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'))
        app.device = DEVICE
        with patch.object(launcher.subprocess, 'run') as run:
            app.foreground()
            args = run.call_args.args[0]
            self.assertNotIn('-n', args)
            self.assertEqual(args[-2:], ['-CurrentDeviceUDID', DEVICE])

    def test_start_failure_is_safe_and_reported(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'), self.lock_path)
        child = Mock()
        child.poll.return_value = 23
        with patch.object(app, 'validate'), patch.object(app, 'find_existing', return_value=None), patch.object(app, 'spawn', return_value=child), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(launcher.LaunchError, 'no pudo iniciar'):
                app.start()

    def test_spawn_uses_inherited_lock_no_terminal_or_output_logs(self):
        app = launcher.DesktopLauncher(Path('/fixture/Papigiras-LAB'))
        with patch.object(launcher.subprocess, 'Popen') as popen:
            app.spawn(7)
            self.assertEqual(popen.call_args.kwargs['pass_fds'], (7,))
            self.assertEqual(popen.call_args.kwargs['stdout'], subprocess.DEVNULL)
            self.assertEqual(popen.call_args.kwargs['stderr'], subprocess.DEVNULL)
            self.assertTrue(popen.call_args.kwargs['start_new_session'])
            self.assertEqual(popen.call_args.args[0][-1], 'run')


if __name__ == '__main__':
    unittest.main(verbosity=2)
