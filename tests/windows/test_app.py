import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PySide6.QtCore import QCoreApplication, QProcess
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


app = module("gitpulse_app", ROOT / "windows/app.py")
packages = module("gitpulse_packages", ROOT / "windows/package-manifests.py")


class SettingsTests(unittest.TestCase):
    def test_round_trip_preserves_unknown_keys_and_unicode_tokens(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested/settings.json"
            app.write_settings(path, {"accounts": "秘密", "futureSetting": True})
            app.write_settings(path, {"glass": False})
            self.assertEqual(
                app.read_settings(path),
                {"accounts": "秘密", "futureSetting": True, "glass": False},
            )
            self.assertEqual(list(path.parent.glob("*.tmp")), [])

    def test_failed_replace_preserves_original(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            app.write_settings(path, {"accounts": "original"})
            with patch.object(app.os, "replace", side_effect=OSError("locked")):
                with self.assertRaises(OSError):
                    app.write_settings(path, {"accounts": "replacement"})
            self.assertEqual(app.read_settings(path), {"accounts": "original"})
            self.assertEqual(list(path.parent.glob("*.tmp")), [])

    def test_corrupt_settings_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            for contents in ("{broken", "[]", "null"):
                path.write_text(contents)
                with self.assertRaises(ValueError):
                    app.write_settings(path, {"accounts": ""})
                self.assertEqual(path.read_text(), contents)

    def test_windows_roaming_path(self):
        with (
            patch.object(app.sys, "platform", "win32"),
            patch.dict(os.environ, {"APPDATA": "/example/Roaming"}),
        ):
            self.assertEqual(
                app.settings_path(),
                Path("/example/Roaming/gitpulse/hyprland-settings.json"),
            )


class CliTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.application = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.backend = app.Backend(Path("unused"))

    def tearDown(self):
        self.backend.close()

    def test_cli_is_opt_in_and_selftest_cannot_enable_it(self):
        with patch.object(self.backend.process, "start") as start:
            self.backend.refreshCli()
            start.assert_not_called()
            self.backend.testing = True
            self.backend.setCliEnabled(True)
            start.assert_not_called()
            self.assertFalse(self.backend.enabled)

    def test_success_and_failure_do_not_retain_old_credentials(self):
        self.backend.enabled = True
        with patch.object(self.backend, "process") as process:
            process.readAllStandardOutput.return_value = b"test-token\n"
            self.backend._finished(0, QProcess.NormalExit)
            self.assertEqual(
                (self.backend.cliToken, self.backend.cliState), ("test-token", "ok")
            )
            self.backend._finished(1, QProcess.NormalExit)
            self.assertEqual(
                (self.backend.cliToken, self.backend.cliState), ("", "unauthenticated")
            )

    def test_missing_cli_and_disable_clear_token(self):
        self.backend.enabled = True
        self.backend._publish("old-token", "ok")
        self.backend._failed(QProcess.FailedToStart)
        self.assertEqual(
            (self.backend.cliToken, self.backend.cliState), ("", "missing")
        )
        self.backend.setCliEnabled(False)
        self.assertEqual((self.backend.cliToken, self.backend.cliState), ("", ""))

    def test_selftest_ignores_settings_and_never_writes(self):
        self.backend.testing = True
        with (
            patch.object(app, "read_settings", side_effect=AssertionError),
            patch.object(app, "write_settings", side_effect=AssertionError),
        ):
            self.assertEqual(self.backend.loadSettings(), "{}")
            self.backend.saveSettings('{"accounts":"test"}')


class PackageTests(unittest.TestCase):
    def test_manifests_match_assets_and_installer_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            assets = Path(directory)
            portable = assets / "gitpulse-windows-2.0.4.zip"
            with zipfile.ZipFile(portable, "w") as archive:
                archive.writestr("GitPulse/GitPulse.exe", b"portable fixture")
            installer = assets / "GitPulse-Setup-2.0.4.exe"
            installer.write_bytes(b"installer fixture")
            output = assets / "manifests"
            packages.generate("v2.0.4", assets, output)
            scoop = json.loads((output / "gitpulse.json").read_text())
            self.assertEqual(
                scoop["architecture"]["64bit"]["hash"], packages.sha256(portable)
            )
            self.assertIn(
                "/Muddyblack/kde-gitpulse/releases/download/v2.0.4/",
                scoop["architecture"]["64bit"]["url"],
            )
            self.assertEqual(scoop["license"], "MIT")
            with zipfile.ZipFile(output / "gitpulse-winget-2.0.4.zip") as archive:
                self.assertEqual(len(archive.namelist()), 3)
                data = archive.read(
                    "manifests/m/Muddyblack/GitPulse/2.0.4/Muddyblack.GitPulse.installer.yaml"
                ).decode()
                self.assertIn(packages.sha256(installer).upper(), data)
                self.assertIn(packages.PRODUCT_CODE, data)
            self.assertIn(
                packages.PRODUCT_CODE.removesuffix("_is1"),
                (ROOT / "windows/installer.iss").read_text(),
            )

    def test_prerelease_manifest_is_rejected(self):
        with self.assertRaises(ValueError):
            packages.generate("2.0.4-rc1", Path("."), Path("."))

    def test_wrong_zip_layout_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            assets = Path(directory)
            with zipfile.ZipFile(assets / "gitpulse-windows-2.0.4.zip", "w") as archive:
                archive.writestr("wrong.exe", b"fixture")
            (assets / "GitPulse-Setup-2.0.4.exe").write_bytes(b"fixture")
            with self.assertRaises(ValueError):
                packages.generate("2.0.4", assets, assets / "output")


if __name__ == "__main__":
    unittest.main()
