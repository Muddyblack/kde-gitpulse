"""Generate Scoop/WinGet manifests from the exact GitPulse release assets."""

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

HOMEPAGE = "https://github.com/Muddyblack/kde-gitpulse"
PACKAGE_ID = "Muddyblack.GitPulse"
# Must match installer.iss's AppId + "_is1".
PRODUCT_CODE = "{302D74EA-C6EF-4F3F-B7DA-377E938CAC27}_is1"
DESCRIPTION = "GitHub, GitLab and Forgejo notifications in your system tray."


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def generate(version, assets, output):
    # Stable release tags only: never produce public URLs for CI/prerelease builds.
    version = version.removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a stable version such as 3.2.0 or v3.2.0")
    portable = f"gitpulse-windows-{version}.zip"
    installer = f"GitPulse-Setup-{version}.exe"
    portable_hash = sha256(assets / portable)
    installer_hash = sha256(assets / installer)
    with zipfile.ZipFile(assets / portable) as archive:
        if "GitPulse/GitPulse.exe" not in archive.namelist():
            raise ValueError("Portable ZIP must contain GitPulse/GitPulse.exe")
    base = f"{HOMEPAGE}/releases/download/v{version}"
    output.mkdir(parents=True, exist_ok=True)
    scoop = {
        "version": version,
        "description": DESCRIPTION,
        "homepage": HOMEPAGE,
        "license": "MIT",
        "architecture": {"64bit": {"url": f"{base}/{portable}", "hash": portable_hash}},
        "extract_dir": "GitPulse",
        "shortcuts": [["GitPulse.exe", "GitPulse"]],
        "notes": "Quit GitPulse before updating. Settings are kept.",
        "checkver": "github",
        "autoupdate": {
            "architecture": {
                "64bit": {
                    "url": f"{HOMEPAGE}/releases/download/v$version/gitpulse-windows-$version.zip"
                }
            },
        },
    }
    (output / "gitpulse.json").write_text(
        json.dumps(scoop, indent=4) + "\n", encoding="utf-8"
    )

    # JSON-quoted scalar values are also valid YAML; the surrounding YAML is
    # deliberately plain so WinGet's restricted parser can read it.
    common = f'PackageIdentifier: {PACKAGE_ID}\nPackageVersion: "{version}"\n'
    manifests = {
        f"{PACKAGE_ID}.yaml": common
        + "DefaultLocale: en-US\nManifestType: version\nManifestVersion: 1.6.0\n",
        f"{PACKAGE_ID}.locale.en-US.yaml": common
        + f"""PackageLocale: en-US
Publisher: Muddyblack
PublisherUrl: {HOMEPAGE}
PublisherSupportUrl: {HOMEPAGE}/issues
PackageName: GitPulse
PackageUrl: {HOMEPAGE}
License: MIT
LicenseUrl: {HOMEPAGE}/blob/v{version}/LICENSE
ShortDescription: {DESCRIPTION}
Moniker: gitpulse
ManifestType: defaultLocale
ManifestVersion: 1.6.0
""",
        f"{PACKAGE_ID}.installer.yaml": common
        + f"""InstallerType: inno
Scope: user
UpgradeBehavior: install
InstallerSwitches:
  Custom: /TASKS=""
Installers:
  - Architecture: x64
    InstallerUrl: {base}/{installer}
    InstallerSha256: {installer_hash.upper()}
    ProductCode: '{PRODUCT_CODE}'
    AppsAndFeaturesEntries:
      - DisplayName: GitPulse
        Publisher: Muddyblack
        DisplayVersion: "{version}"
        ProductCode: '{PRODUCT_CODE}'
ManifestType: installer
ManifestVersion: 1.6.0
""",
    }
    manifest_dir = (
        output / "winget" / "manifests" / "m" / "Muddyblack" / "GitPulse" / version
    )
    manifest_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        output / f"gitpulse-winget-{version}.zip", "w", zipfile.ZIP_DEFLATED
    ) as archive:
        for name, contents in manifests.items():
            path = manifest_dir / name
            data = contents.encode("utf-8")
            path.write_bytes(data)
            archive.writestr(path.relative_to(output / "winget").as_posix(), data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--assets", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path, default=Path("dist/package-manifests"))
    args = parser.parse_args()
    generate(args.version, args.assets, args.output)


if __name__ == "__main__":
    main()
