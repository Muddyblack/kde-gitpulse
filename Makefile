.PHONY: help view view-h install uninstall pack tag test lint format shots
.DEFAULT_GOAL := help

# Qt tooling: prefer the dev shell, fall back to whatever is on PATH.
QMLLINT   ?= $(shell command -v qmllint 2>/dev/null)
QMLFORMAT ?= $(shell command -v qmlformat 2>/dev/null)
QMLRUN    ?= $(shell command -v qml 2>/dev/null)
QML_FILES := $(shell find package/contents/ui hyprland -name '*.qml' 2>/dev/null) shell.qml

# Derive the module path from the runtime itself. Without this, an environment
# whose QML2_IMPORT_PATH points at another Qt (a stale Qt 5 entry is enough)
# shadows QtQuick.Controls and the tests fail for reasons unrelated to the code.
QML_MODULES := $(if $(QMLRUN),$(abspath $(dir $(QMLRUN))/../lib/qt-6/qml))
TEST_ENV := QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
            QML2_IMPORT_PATH=$(QML_MODULES) QML_IMPORT_PATH=$(QML_MODULES)

help: ## list targets
	@awk 'BEGIN{FS=":.*##"} /^[a-z][a-zA-Z0-9_-]+:.*##/ {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

view: ## preview widget (planar)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view; \
	else \
	  plasmoidviewer -a package -f planar; \
	fi

view-h: ## preview widget (horizontal panel form factor)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view -- horizontal; \
	else \
	  plasmoidviewer -a package -f horizontal; \
	fi

install: ## install into the local Plasma session and restart plasmashell
	@./test_install.sh

uninstall: ## remove the locally installed copy
	@kpackagetool6 --type Plasma/Applet --remove org.muddyblack.gitpulse || true

test: ## run the shared-core unit tests (needs the `qml` runtime)
	@if [ -z "$(QMLRUN)" ]; then \
	  echo "qml runtime not found — install qt6.qtdeclarative or run 'nix develop'"; exit 1; \
	fi
	@# QT_FORCE_STDERR_LOGGING: without it Qt routes console.log to the journal
	@# on systemd distributions and the run looks silent but passing.
	@$(TEST_ENV) $(QMLRUN) tests/run-tests.qml
	@$(TEST_ENV) $(QMLRUN) tests/engine-smoke.qml
	@# Renders the whole Quickshell UI offscreen. Nothing may print a binding
	@# error, and the run must reach its own "rendered everything" line.
	@out="$$($(TEST_ENV) $(QMLRUN) tests/hyprland-smoke.qml 2>&1)"; \
	 echo "$$out" | sort -u; \
	 if echo "$$out" | grep -qE "TypeError|ReferenceError|Unable to assign|is not defined|unavailable"; then \
	   echo "  ✗ hyprland-smoke: QML reported binding errors"; exit 1; \
	 fi; \
	 if ! echo "$$out" | grep -q "rendered every tab"; then \
	   echo "  ✗ hyprland-smoke: did not finish"; exit 1; \
	 fi; \
	 echo "  ✓ hyprland-smoke: every tab and state rendered clean"

shots: ## render the Quickshell UI to PNGs in ./build/shots (needs the `qml` runtime)
	@mkdir -p build/shots
	@$(TEST_ENV) $(QMLRUN) tests/hyprland-smoke.qml -- --shot "$(PWD)/build/shots" >/dev/null 2>&1
	@ls build/shots

lint: ## qmllint every QML file
	@if [ -z "$(QMLLINT)" ]; then echo "qmllint not found — run 'nix develop'"; exit 1; fi
	@$(QMLLINT) --unresolved-type info $(QML_FILES)

format: ## qmlformat every QML file in place
	@if [ -z "$(QMLFORMAT)" ]; then echo "qmlformat not found — run 'nix develop'"; exit 1; fi
	@$(QMLFORMAT) -i $(QML_FILES)

pack: ## build the .plasmoid archive
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#pack; \
	else \
	  ver=$$(grep -oE '"Version":[[:space:]]*"[^"]+"' package/metadata.json | head -1 | sed -E 's/.*"([^"]+)"$$/\1/'); \
	  out="$$PWD/gitpulse-$$ver.plasmoid"; \
	  rm -f "$$out"; \
	  (cd package && zip -r "$$out" . -x '*.swp' '*~'); \
	  echo "wrote $$out"; \
	fi

tag: ## bump version, commit, tag, push
	@./tag.sh
