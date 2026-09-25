import os

ROOT = os.path.abspath(os.path.join(SPECPATH, ".."))  # noqa: F821 — set by PyInstaller

datas = [
    (os.path.join(ROOT, "windows", "qml"), os.path.join("windows", "qml")),
    # Preserve relative imports between the shared UI, engine and JS.
    (os.path.join(ROOT, "package", "contents"), os.path.join("package", "contents")),
    (os.path.join(ROOT, "package", "icon.png"), "package"),
    (os.path.join(ROOT, "hyprland"), "hyprland"),
    (os.path.join(ROOT, "tests", "Fixtures.js"), "tests"),
]

a = Analysis(  # noqa: F821
    [os.path.join(ROOT, "windows", "app.py")],
    pathex=[os.path.join(ROOT, "windows")],
    hiddenimports=[],
    datas=datas,
    excludes=["tkinter"],
)
pyz = PYZ(a.pure)  # noqa: F821
exe = EXE(  # noqa: F821
    pyz,
    a.scripts,
    # UTF-8 mode: without it Windows' default text encoding is the ANSI code
    # page (cp1252), for open() and subprocess output alike.
    [("X utf8", None, "OPTION")],
    exclude_binaries=True,
    name="GitPulse",
    console=False,
    icon=os.path.join(ROOT, "package", "icon.png"),
)
coll = COLLECT(exe, a.binaries, a.datas, name="GitPulse")  # noqa: F821
