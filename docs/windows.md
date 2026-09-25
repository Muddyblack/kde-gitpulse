# Windows tray app

GitPulse has a PySide6 tray host for the same popup, account settings and forge
engine used by the Hyprland frontend. It supports GitHub, GitLab, Codeberg and
Forgejo accounts without requiring Plasma or Quickshell.

This port has been checked headlessly on Linux. The Windows workflow tests
source and packaged builds; a real Windows desktop still needs the manual
checks below. No Windows release has been published as part of this change.

## Run from a checkout

On Windows, with Python 3.12 or newer:

```powershell
pip install -r windows/requirements.txt
python windows/app.py
```

On Linux, `make run-windows` uses the isolated `nix develop path:.#windows`
environment. `make test-windows` runs settings/packaging tests and renders every
popup tab plus Settings and Project Info using offline fixtures. The selftest
never loads your settings, reads CLI credentials, or writes settings:

```powershell
python -m unittest discover -s tests/windows -v
python windows/app.py --selftest
```

Click the tray icon to toggle the popup. Right-click for Open, Refresh,
Settings, Start with Windows, and Quit. Escape or the popup's close button
hides it; Quit exits the app. Starting a second copy opens the existing popup;
`--settings` opens its settings page. The first launch opens the popup so you
can configure accounts and find the tray icon (Windows may put it in overflow).

Add accounts in Settings using a token, or opt into an existing GitHub CLI
login. The optional `gh` executable must be on PATH and authenticated with
`gh auth login`; GitPulse invokes `gh auth token` directly and refreshes that
credential every 15 minutes. It does not bundle the CLI.

Settings, including manually entered tokens, are stored as plain JSON at
`%APPDATA%\gitpulse\hyprland-settings.json`, using the Hyprland settings format.
The host uses atomic replacement and keeps unknown keys. Invalid existing
settings stop startup with an error instead of being overwritten. Logs are
under Qt's per-user local application data directory, normally
`%LOCALAPPDATA%\Muddyblack\GitPulse\tray.log`.

## Build and distribute

Build on Windows (PyInstaller does not cross-compile):

```powershell
pip install -r windows/build-requirements.txt
pyinstaller --noconfirm windows/gitpulse.spec
& "dist/GitPulse/GitPulse.exe" --selftest
windows/build-installer.ps1 -Version 2.0.4
```

The resulting folder is `dist/GitPulse/`; the installer is
`GitPulse-Setup-<version>.exe`. It installs per user without administrator
rights, adds a Start menu entry, and offers optional desktop and autostart
shortcuts. Updates preserve settings and the autostart preference. The app's
tray switch and installer use the same `HKCU` Run value, `GitPulse`.
Uninstall removes autostart but keeps settings. Builds are currently unsigned.

`.github/workflows/windows.yml` runs on relevant pushes and pull requests,
and can be started manually. It tests Linux and Windows, builds the portable
ZIP and Inno installer, and smoke-tests the bundled executable. Tag releases
invoke the same workflow and attach its artifacts after the Plasma release.
A Windows failure does not prevent the `.plasmoid` release.

Stable releases also generate a Scoop manifest and a ZIP of WinGet manifests,
using hashes of the exact release binaries. Generate them locally with:

```powershell
python windows/package-manifests.py --version 2.0.4
```

The output is under `dist/package-manifests/`. WinGet files use the identifier
`Muddyblack.GitPulse`; they are ready for validation and separate submission,
not automatically registered in the public catalog. Scoop can install the
release's `gitpulse.json` URL once those assets have been published. Use one
installation method at a time, quit before updates, and turn off Start with
Windows before uninstalling a portable/Scoop copy. No Microsoft Store package
or signing is configured.

## Check on a real Windows desktop

- Open/close from the tray, second launch, Settings, Escape and Quit.
- Add a token account and a CLI account; restart and verify both survive.
- Refresh inbox, actions, pulls, issues, profile, Copilot and service health;
  check account switching, mark-as-read and opening browser links.
- Confirm the CLI refresh produces no console window.
- Check popup placement with taskbars on different edges, multiple monitors,
  and 100%, 125% and 150% display scaling.
- Enable/disable autostart, sign out/in, then install an update and uninstall.
- Verify portable and installed builds include all QML modules and icons.

UI and API behavior live in `hyprland/` and `package/contents/`. The Windows
host owns window placement, tray, settings persistence, CLI lookup and startup.
When adding a setting or engine binding to `GitpulseShell.qml`, update the
corresponding wiring in `windows/qml/Main.qml` too.
