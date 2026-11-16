#!/usr/bin/env python3
"""Guard against accidentally signing a device app or a different checkout."""
import plistlib
import tempfile
import unittest
from pathlib import Path
from sign_qa_simulator import simulator_artifact


class SimulatorArtifactScopeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.app = self.root / "build/ios/iphonesimulator/Runner.app"
        self.app.mkdir(parents=True)
        self.info = {
            "CFBundleIdentifier": "com.papigiras.lab",
            "CFBundleSupportedPlatforms": ["iPhoneSimulator"],
            "DTPlatformName": "iphonesimulator",
            "CFBundleExecutable": "Runner",
        }
        (self.app / "Runner").write_bytes(b"synthetic-test-executable")
        self.save()

    def save(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def test_accepts_only_expected_qa_artifact(self):
        self.assertEqual(simulator_artifact(self.root), self.app.resolve())

    def test_rejects_real_device_even_if_placed_in_simulator_directory(self):
        self.info.update(CFBundleSupportedPlatforms=["iPhoneOS"], DTPlatformName="iphoneos")
        self.save()
        with self.assertRaises(ValueError):
            simulator_artifact(self.root)

    def test_rejects_other_application(self):
        self.info["CFBundleIdentifier"] = "example.other"
        self.save()
        with self.assertRaises(ValueError):
            simulator_artifact(self.root)

    def test_rejects_symlinked_build_directory(self):
        build = self.root / "build"
        build.rename(self.root / "elsewhere")
        build.symlink_to(self.root / "elsewhere", target_is_directory=True)
        with self.assertRaises(ValueError):
            simulator_artifact(self.root)

    def test_rejects_symlinked_manifest(self):
        info = self.app / "Info.plist"
        info.rename(self.root / "elsewhere.plist")
        info.symlink_to(self.root / "elsewhere.plist")
        with self.assertRaises(ValueError):
            simulator_artifact(self.root)

    def test_rejects_symlinked_executable(self):
        binary = self.app / "Runner"
        binary.rename(self.root / "elsewhere-binary")
        binary.symlink_to(self.root / "elsewhere-binary")
        with self.assertRaises(ValueError):
            simulator_artifact(self.root)

    def test_rejects_unexpected_executable(self):
        self.info["CFBundleExecutable"] = "../Other"
        self.save()
        with self.assertRaises(ValueError):
            simulator_artifact(self.root)


if __name__ == "__main__":
    unittest.main()
