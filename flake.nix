{
  description = "Gitpulse — GitHub activity widget for KDE Plasma 6 and Hyprland/Quickshell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f system);
      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
      appletId = metadata.KPlugin.Id;
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "gitpulse";
            version = metadata.KPlugin.Version;
            src = ./package;

            dontConfigure = true;
            dontBuild = true;

            # Nothing to patch and nothing to wrap: the widget talks to GitHub
            # through QML's own XMLHttpRequest, so it has no interpreter, no
            # helper binary and no runtime closure beyond Plasma itself.
            installPhase = ''
              runHook preInstall

              root=$out/share/plasma/plasmoids/${appletId}
              mkdir -p "$root"
              cp -r . "$root/"

              # Register the icon in the hicolor theme so the Widget Explorer
              # and the Add Widgets dialog can find it.
              mkdir -p "$out/share/icons/hicolor/scalable/apps"
              cp contents/icons/${appletId}.svg \
                 "$out/share/icons/hicolor/scalable/apps/${appletId}.svg"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "GitHub activity widget for KDE Plasma 6";
              license = licenses.mit;
              platforms = platforms.linux;
              homepage = metadata.KPlugin.Website;
            };
          };

          tray-helper = pkgs.stdenv.mkDerivation {
            pname = "gitpulse-tray";
            version = metadata.KPlugin.Version;
            src = ./hyprland/tray;
            nativeBuildInputs = with pkgs; [ cmake ninja qt6.wrapQtAppsHook ];
            buildInputs = with pkgs; [ qt6.qtbase ];
          };
        });

      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          quickshellDesktop = pkgs.makeDesktopItem {
            name = "org.quickshell";
            desktopName = "Quickshell";
            comment = "QtQuick desktop shell runtime";
            # xdg-desktop-portal resolves this entry in the portal daemon's
            # environment, where a flake-only Quickshell is not on PATH.
            exec = "${pkgs.quickshell}/bin/qs";
            icon = appletId;
            terminal = false;
            noDisplay = true;
            categories = [ "Utility" ];
          };
        in {
          view = {
            type = "app";
            program = toString (pkgs.writeShellScript "view" ''
              if [ ! -f "$PWD/package/metadata.json" ]; then
                echo "error: no plasmoid at $PWD/package" >&2
                echo "  'nix run .#view' previews your working copy, so run it from the repo root." >&2
                exit 1
              fi
              exec nix shell nixpkgs#kdePackages.plasma-sdk nixpkgs#kdePackages.plasma-desktop -c plasmoidviewer \
                -a "$PWD/package" -f "''${1:-planar}"
            '');
          };

          pack = {
            type = "app";
            program = toString (pkgs.writeShellScript "pack" ''
              set -euo pipefail
              here="$PWD"
              ver="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$here/package/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
              out="$here/gitpulse-$ver.plasmoid"
              rm -f "$out"
              (cd "$here/package" && ${pkgs.zip}/bin/zip -r "$out" . -x '*.swp' '*~')
              echo "wrote $out"
            '');
          };

          hyprland = {
            type = "app";
            program = toString (pkgs.writeShellScript "gitpulse-hyprland" ''
              set -eu
              # The repo root, not hyprland/ — Quickshell roots its QML sandbox
              # at the entry point's directory, and hyprland/ cannot reach the
              # shared JS under package/. See shell.qml.
              config=${self}/shell.qml
              desktop_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/applications"
              ${pkgs.coreutils}/bin/mkdir -p "$desktop_dir"
              ${pkgs.coreutils}/bin/install -m 0644 \
                ${quickshellDesktop}/share/applications/org.quickshell.desktop \
                "$desktop_dir/org.quickshell.desktop"
              ${self.packages.${system}.tray-helper}/bin/gitpulse-tray \
                ${pkgs.quickshell}/bin/qs "$config" &
              tray_pid=$!
              trap 'kill "$tray_pid" 2>/dev/null || true' EXIT INT TERM
              ${pkgs.quickshell}/bin/qs -p "$config"
            '');
          };
        });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            name = "gitpulse-dev";
            packages = with pkgs; [
              qt6.qtdeclarative # qmllint, qmlformat, qml
              kdePackages.kirigami
              kdePackages.libplasma
              kdePackages.kpackage
              kdePackages.plasma-sdk
              pre-commit
              zip
            ];
            shellHook = ''
              pre-commit install -f --install-hooks
              echo "gitpulse dev shell ready"
              echo "  make help     — list targets (view, install, test, lint, pack)"
            '';
          };
        });
    };
}
