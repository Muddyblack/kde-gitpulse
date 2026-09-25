"""Native tray/window host; the shared QML engine owns all forge requests."""

import argparse
import json
import logging
import os
import subprocess
import sys
import tempfile
from logging.handlers import RotatingFileHandler
from pathlib import Path

from PySide6.QtCore import (
    Property,
    QObject,
    QProcess,
    QStandardPaths,
    QTimer,
    QUrl,
    Signal,
    Slot,
    qInstallMessageHandler,
)
from PySide6.QtGui import QCursor, QIcon
from PySide6.QtNetwork import (
    QLocalServer,
    QLocalSocket,
    QNetworkAccessManager,
    QNetworkRequest,
)
from PySide6.QtQml import QQmlApplicationEngine, QQmlNetworkAccessManagerFactory
from PySide6.QtQuick import QQuickWindow
from PySide6.QtWidgets import QApplication, QMenu, QMessageBox, QSystemTrayIcon
from shiboken6 import delete

ROOT = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parents[1]))
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


class OfflineNetwork(QNetworkAccessManager):
    """Keep selftest fully offline, including the shared Project Info pane."""

    def createRequest(self, operation, request, outgoing=None):
        replacement = QNetworkRequest(request)
        if request.url().scheme() in ("http", "https"):
            if request.url().path().endswith((".png", ".jpg", ".svg")):
                replacement.setUrl(QUrl.fromLocalFile(str(ROOT / "package/icon.png")))
            else:
                replacement.setUrl(QUrl("data:application/json,%5B%5D"))
        return super().createRequest(operation, replacement, outgoing)


class OfflineFactory(QQmlNetworkAccessManagerFactory):
    def create(self, parent):
        return OfflineNetwork(parent)


def settings_path():
    base = (
        Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming")))
        if sys.platform == "win32"
        else Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    )
    return base / "gitpulse" / "hyprland-settings.json"


def read_settings(path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    if not isinstance(data, dict):
        raise ValueError("Settings must contain a JSON object")
    return data


def write_settings(path, data):
    """Preserve unknown settings and atomically replace the file containing tokens."""
    merged = read_settings(path)
    merged.update(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(
        dir=path.parent, prefix=".settings-", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(merged, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def autostart(enabled=None):
    if sys.platform != "win32":
        return False
    import winreg

    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
        if enabled is True:
            command = [sys.executable]
            if not getattr(sys, "frozen", False):
                command.append(str(Path(__file__).resolve()))
            winreg.SetValueEx(
                key, "GitPulse", 0, winreg.REG_SZ, subprocess.list2cmdline(command)
            )
        elif enabled is False:
            try:
                winreg.DeleteValue(key, "GitPulse")
            except FileNotFoundError:
                pass
        try:
            return bool(winreg.QueryValueEx(key, "GitPulse")[0])
        except FileNotFoundError:
            return False


class Backend(QObject):
    cliChanged = Signal()
    summaryChanged = Signal(str)
    error = Signal(str)

    def __init__(self, path, selftest=False):
        super().__init__()
        self.path = path
        self.testing = selftest
        self.enabled = False
        self.token = ""
        self.state = ""
        self.process = QProcess(self)
        self.process.setProgram("gh")
        self.process.setArguments(["auth", "token"])
        self.process.finished.connect(self._finished)
        self.process.errorOccurred.connect(self._failed)
        self.timeout = QTimer(self)
        self.timeout.setSingleShot(True)
        self.timeout.setInterval(15000)
        self.timeout.timeout.connect(self.process.kill)
        self.refresh_timer = QTimer(self)
        self.refresh_timer.setInterval(15 * 60 * 1000)
        self.refresh_timer.timeout.connect(self.refreshCli)

    @Property(bool, constant=True)
    def selftest(self):
        return self.testing

    @Property(str, notify=cliChanged)
    def cliToken(self):
        return self.token

    @Property(str, notify=cliChanged)
    def cliState(self):
        return self.state

    def _publish(self, token, state):
        self.token, self.state = token, state
        self.cliChanged.emit()

    @Slot(bool)
    def setCliEnabled(self, enabled):
        self.enabled = enabled and not self.testing
        if self.enabled:
            self.refresh_timer.start()
            self.refreshCli()
        else:
            self.refresh_timer.stop()
            self.process.kill()
            self._publish("", "")

    @Slot()
    def refreshCli(self):
        if not self.enabled or self.process.state() != QProcess.NotRunning:
            return
        self._publish(self.token, "probing")
        # QProcess starts the executable directly, without cmd.exe or a console.
        self.process.start()
        self.timeout.start()

    def _finished(self, code, status):
        self.timeout.stop()
        output = (
            bytes(self.process.readAllStandardOutput())
            .decode("utf-8", errors="replace")
            .strip()
        )
        self.process.readAllStandardError()  # Never log CLI credentials or stderr.
        if self.enabled:
            token = output if code == 0 and status == QProcess.NormalExit else ""
            self._publish(token, "ok" if token else "unauthenticated")

    def _failed(self, error):
        self.timeout.stop()
        if self.enabled:
            self._publish(
                "", "missing" if error == QProcess.FailedToStart else "unauthenticated"
            )

    @Slot(result=str)
    def loadSettings(self):
        return json.dumps({} if self.testing else read_settings(self.path))

    @Slot(str)
    def saveSettings(self, value):
        if self.testing:
            return
        try:
            write_settings(self.path, json.loads(value))
        except (OSError, ValueError):
            self.error.emit(
                "Could not save settings. Check the settings file and directory permissions."
            )

    @Slot(str)
    def setSummary(self, value):
        self.summaryChanged.emit(value)

    def close(self):
        self.refresh_timer.stop()
        self.timeout.stop()
        self.process.kill()
        self.process.waitForFinished(1000)


def configure_selftest_runtime():
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    os.environ["QT_QUICK_BACKEND"] = "software"
    if sys.platform == "win32" and "QT_QPA_FONTDIR" not in os.environ:
        # The offscreen platform uses Qt's basic font database, which
        # otherwise looks for a fonts directory that PySide6 does not ship.
        fonts = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
        if fonts.is_dir():
            os.environ["QT_QPA_FONTDIR"] = str(fonts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--selftest",
        action="store_true",
        help="Render all tabs without credentials, settings writes or network",
    )
    parser.add_argument("--settings", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        configure_selftest_runtime()
    app = QApplication(sys.argv[:1])
    app.setApplicationName("GitPulse")
    app.setOrganizationName("Muddyblack")
    app.setQuitOnLastWindowClosed(False)
    path = settings_path()
    if not args.selftest:
        logdir = Path(
            QStandardPaths.writableLocation(QStandardPaths.AppLocalDataLocation)
        )
        logdir.mkdir(parents=True, exist_ok=True)
        logging.basicConfig(
            handlers=[
                RotatingFileHandler(
                    logdir / "tray.log",
                    maxBytes=512000,
                    backupCount=1,
                    encoding="utf-8",
                )
            ],
            level=logging.WARNING,
        )
    warnings = []

    def qt_message(kind, context, message):
        # Never capture network payloads or tokens; only QML source diagnostics.
        if args.selftest:
            warnings.append(message)
            print(message, file=sys.stderr)
        elif "qml" in message.lower():
            logging.warning(message)

    qInstallMessageHandler(qt_message)
    server = QLocalServer(app)
    server.setSocketOptions(QLocalServer.UserAccessOption)
    if not args.selftest:
        socket = QLocalSocket()
        socket.connectToServer("Muddyblack.GitPulse")
        if socket.waitForConnected(500):
            socket.write(b"settings" if args.settings else b"open")
            socket.waitForBytesWritten(1000)
            return 0
        QLocalServer.removeServer("Muddyblack.GitPulse")
        if not server.listen("Muddyblack.GitPulse"):
            QMessageBox.critical(
                None, "GitPulse", "Could not start the single-instance server."
            )
            return 1
        try:
            read_settings(path)
        except (ValueError, OSError):
            QMessageBox.critical(
                None,
                "GitPulse",
                f"Could not read settings at {path}. Repair the file before restarting. It has been left untouched.",
            )
            return 1
    backend = Backend(path, args.selftest)
    engine = QQmlApplicationEngine()
    if args.selftest:
        offline = OfflineFactory()
        engine.setNetworkAccessManagerFactory(offline)
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(ROOT / "windows/qml/Main.qml")))
    if not engine.rootObjects():
        return 1
    window = engine.rootObjects()[0]
    if not isinstance(window, QQuickWindow):
        return 1
    app.aboutToQuit.connect(window.saveSettings)
    app.aboutToQuit.connect(backend.close)

    def show(settings=False):
        if settings:
            window.openSettings()
        screen = app.screenAt(QCursor.pos()) or app.primaryScreen()
        area = screen.availableGeometry()
        window.setWidth(min(440, area.width()))
        window.setHeight(min(620, area.height()))
        window.setPosition(
            area.right() - window.width() - 12, area.bottom() - window.height() - 12
        )
        window.show()
        window.raise_()
        window.requestActivate()

    def receive():
        client = server.nextPendingConnection()

        def read():
            message = bytes(client.readAll())
            show(message == b"settings")
            client.disconnectFromServer()

        client.readyRead.connect(read)
        client.disconnected.connect(client.deleteLater)
        if client.bytesAvailable():
            read()

    server.newConnection.connect(receive)
    if args.selftest:
        window.show()
        QTimer.singleShot(15000, lambda: app.exit(1))
        step = [0]

        def smoke():
            if step[0] >= window.property("smokeSteps"):
                app.exit(1 if warnings else 0)
                return
            window.smokeStep(step[0])
            step[0] += 1
            QTimer.singleShot(150, smoke)

        QTimer.singleShot(150, smoke)
    else:
        tray = QSystemTrayIcon(QIcon(str(ROOT / "package/icon.png")), app)
        tray.setToolTip(window.property("traySummary"))
        backend.summaryChanged.connect(tray.setToolTip)
        backend.error.connect(
            lambda message: QMessageBox.warning(None, "GitPulse", message)
        )
        menu = QMenu()
        menu.addAction("Open GitPulse", lambda: show())
        menu.addAction("Refresh", window.refresh)
        menu.addAction("Settings", lambda: show(True))
        if sys.platform == "win32":
            action = menu.addAction("Start with Windows")
            action.setCheckable(True)
            action.setChecked(autostart())

            def set_startup(enabled):
                try:
                    autostart(enabled)
                except OSError:
                    action.setChecked(not enabled)
                    QMessageBox.warning(
                        None, "GitPulse", "Could not change Start with Windows."
                    )

            action.triggered.connect(set_startup)
        menu.addSeparator()
        menu.addAction("Quit", app.quit)
        tray.setContextMenu(menu)

        def activate(reason):
            if reason == QSystemTrayIcon.Trigger:
                window.hide() if window.isVisible() else show()

        tray.activated.connect(activate)
        tray.show()
        if (
            args.settings
            or not path.exists()
            or not QSystemTrayIcon.isSystemTrayAvailable()
        ):
            show(args.settings)
    result = app.exec()
    # Tear down QML before its context object, avoiding shutdown binding errors.
    delete(engine)
    return result


if __name__ == "__main__":
    raise SystemExit(main())
