// Gitpulse — Quickshell frontend for Hyprland.
//
// Shares the entire GitHub layer with the Plasma widget: Engine.qml and the JS
// under package/contents/code/ are the same files, not copies. Only the
// presentation differs, because Kirigami is a Plasma dependency this side does
// not want to impose.
//
// This file is wiring: settings, engine, IPC, window. The popup's insides are
// PopupChrome.qml.
import QtQuick
import Quickshell
import Quickshell.Io

// Resolvable only because the config root is the repository root — see
// ../shell.qml for why this file is not the entry point.
import "../package/contents/ui/engine" as EngineNS
import "../package/contents/code/Forge.js" as Forge

ShellRoot {
    id: root

    property bool popupVisible: false
    property bool settingsVisible: false
    property string currentTab: "inbox"

    readonly property var tabs: {
        var t = [
            {
                id: "inbox",
                label: qsTr("Inbox")
            }
        ];
        if (cfg.actionsEnabled)
            t.push({
                id: "actions",
                label: qsTr("Actions")
            });
        if (cfg.pullsEnabled)
            t.push({
                id: "pulls",
                label: qsTr("Pulls")
            });
        if (cfg.issuesEnabled)
            t.push({
                id: "issues",
                label: qsTr("Issues")
            });
        if (cfg.profileEnabled)
            t.push({
                id: "profile",
                label: qsTr("Profile")
            });
        if (cfg.copilotEnabled)
            t.push({
                id: "copilot",
                label: qsTr("Copilot")
            });
        if (cfg.statusEnabled)
            t.push({
                id: "status",
                label: qsTr("Status")
            });
        return t;
    }

    readonly property string configPath: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        var base = (xdg && xdg !== "") ? xdg : (Quickshell.env("HOME") + "/.config");
        return base + "/gitpulse/hyprland-settings.json";
    }

    function mute(repo) {
        var list = String(cfg.mutedRepos || "").split(",").map(s => s.trim()).filter(s => s.length);
        if (list.indexOf(repo) < 0)
            list.push(repo);
        cfg.mutedRepos = list.join(", ");
    }

    // ── accounts ────────────────────────────────────────────────────────────
    //
    // The same JSON the Plasma side stores, so an account set up in one
    // frontend can be pasted into the other unchanged.
    readonly property var accounts: Forge.parse(cfg.accounts)

    /**
     * Carry a single-token config file into the account list, once.
     *
     * Quickshell rewrites the whole JSON on any change, so the legacy keys are
     * blanked in the same pass rather than left to shadow the new list.
     */
    function migrateLegacyConfig() {
        if (cfg.accounts !== "")
            return;
        var moved = Forge.migrate(cfg.token, cfg.graphqlToken, cfg.useGhCli);
        if (!moved.length)
            return;
        cfg.accounts = Forge.stringify(moved);
        cfg.token = "";
        cfg.graphqlToken = "";
        cfg.useGhCli = false;
    }

    Theme {
        id: ui

        accent: cfg.accent
        opacity: cfg.backgroundOpacity
    }

    GhToken {
        id: gh

        enabled: root.accounts.some(a => a.useCli)
    }

    // ── persisted settings ──────────────────────────────────────────────────
    FileView {
        id: settingsFile

        path: root.configPath
        watchChanges: true
        // A missing file on first launch is the normal case, not a fault —
        // writeAdapter() creates it, parent directories and all.
        printErrors: false
        // A token lives in here, so atomic writes stop a crash mid-save from
        // truncating it.
        atomicWrites: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: cfg

            property string accounts: ""
            // Read once by migrateLegacyConfig(), then blanked. Kept in the
            // adapter so an existing config file still has somewhere to land.
            property string token: ""
            property string graphqlToken: ""
            property bool useGhCli: false
            property bool quietHoursEnabled: false
            property int quietFromHour: 22
            property int quietToHour: 8
            property bool actionsEnabled: true
            property bool pullsEnabled: true
            property bool issuesEnabled: true
            property bool profileEnabled: true
            property bool copilotEnabled: false
            property bool statusEnabled: true
            property bool participatingOnly: false
            property int inboxIntervalSec: 60
            property int searchIntervalSec: 180
            property int actionsIntervalSec: 300
            property int watchRepoCount: 6
            property string repoAllowlist: ""
            property string mutedRepos: ""
            property string copilotOrg: ""
            property string accent: "#3daee9"
            property real backgroundOpacity: 0.85
            property bool glass: true
        }
    }

    // ── shared engine ───────────────────────────────────────────────────────
    //
    // Singleton (package/contents/ui/engine/): Quickshell only ever runs one
    // shell process, so this is just the same object the KDE side binds to
    // when it's the one running — one poller per process either way, kept
    // consistent rather than instantiated fresh here.
    readonly property var core: EngineNS.Engine

    Binding {
        target: root.core
        property: "accountsJson"
        value: cfg.accounts
    }
    Binding {
        target: root.core
        property: "cliToken"
        value: gh.token
    }
    Binding {
        target: root.core
        property: "quietFromHour"
        value: cfg.quietHoursEnabled ? cfg.quietFromHour : 0
    }
    Binding {
        target: root.core
        property: "quietToHour"
        value: cfg.quietHoursEnabled ? cfg.quietToHour : 0
    }
    Binding {
        target: root.core
        property: "actionsEnabled"
        value: cfg.actionsEnabled
    }
    Binding {
        target: root.core
        property: "pullsEnabled"
        value: cfg.pullsEnabled
    }
    Binding {
        target: root.core
        property: "issuesEnabled"
        value: cfg.issuesEnabled
    }
    Binding {
        target: root.core
        property: "profileEnabled"
        value: cfg.profileEnabled
    }
    Binding {
        target: root.core
        property: "copilotEnabled"
        value: cfg.copilotEnabled
    }
    Binding {
        target: root.core
        property: "statusEnabled"
        value: cfg.statusEnabled
    }
    Binding {
        target: root.core
        property: "participatingOnly"
        value: cfg.participatingOnly
    }
    Binding {
        target: root.core
        property: "inboxIntervalSec"
        value: cfg.inboxIntervalSec
    }
    Binding {
        target: root.core
        property: "searchIntervalSec"
        value: cfg.searchIntervalSec
    }
    Binding {
        target: root.core
        property: "actionsIntervalSec"
        value: cfg.actionsIntervalSec
    }
    Binding {
        target: root.core
        property: "watchRepoCount"
        value: cfg.watchRepoCount
    }
    Binding {
        target: root.core
        property: "repoAllowlist"
        value: cfg.repoAllowlist
    }
    Binding {
        target: root.core
        property: "mutedRepos"
        value: cfg.mutedRepos
    }
    Binding {
        target: root.core
        property: "copilotOrg"
        value: cfg.copilotOrg
    }

    Connections {
        target: root.core
        function onMuteRequested(repo) {
            root.mute(repo);
        }
    }

    Component.onCompleted: {
        root.migrateLegacyConfig();
        root.core.start();
    }

    // ── tray IPC ────────────────────────────────────────────────────────────
    IpcHandler {
        target: "panel"

        function toggle(): void {
            root.popupVisible = !root.popupVisible;
        }

        function show(): void {
            root.popupVisible = true;
        }

        function hide(): void {
            root.popupVisible = false;
        }

        function refresh(): void {
            core.refreshAll(false);
        }

        function badge(): string {
            return String(core.badge.needsYou);
        }

        function summary(): string {
            if (!core.configured)
                return qsTr("Gitpulse — not configured");
            if (core.badge.needsYou === 0)
                return qsTr("Gitpulse — nothing needs you");
            return qsTr("Gitpulse — %1 need you").arg(core.badge.needsYou);
        }

        function quit(): void {
            Qt.quit();
        }
    }

    // ── popup ───────────────────────────────────────────────────────────────
    PanelWindow {
        id: popup

        visible: root.popupVisible
        color: "transparent"
        implicitWidth: 440
        implicitHeight: 620
        margins.top: 10
        margins.right: 10
        focusable: true

        anchors {
            top: true
            right: true
        }

        GlassPanel {
            anchors.fill: parent
            theme: ui
            glass: cfg.glass

            PopupChrome {
                anchors.fill: parent
                anchors.margins: ui.spacing * 1.5
                visible: !root.settingsVisible

                theme: ui
                engine: core
                tabs: root.tabs
                currentTab: root.currentTab
                settingsVisible: root.settingsVisible

                onTabPicked: id => root.currentTab = id
                onSettingsToggled: root.settingsVisible = true
                onCloseRequested: root.popupVisible = false
                onOpenUrl: url => Qt.openUrlExternally(url)
            }

            SettingsPage {
                anchors.fill: parent
                anchors.margins: ui.spacing * 1.5
                visible: root.settingsVisible

                theme: ui
                settings: cfg
                ghState: gh.state
                onClosed: root.settingsVisible = false
            }
        }
    }
}
