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
import "../package/contents/ui" as Core

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

    /** Whichever credential the user chose; the engine only sees the result. */
    readonly property string activeToken: cfg.useGhCli ? gh.token : cfg.token

    Theme {
        id: ui

        accent: cfg.accent
        opacity: cfg.backgroundOpacity
    }

    GhToken {
        id: gh

        enabled: cfg.useGhCli
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

            property string token: ""
            property string graphqlToken: ""
            property bool useGhCli: false
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
    Core.Engine {
        id: core

        token: root.activeToken
        graphqlToken: cfg.graphqlToken
        actionsEnabled: cfg.actionsEnabled
        pullsEnabled: cfg.pullsEnabled
        issuesEnabled: cfg.issuesEnabled
        profileEnabled: cfg.profileEnabled
        copilotEnabled: cfg.copilotEnabled
        statusEnabled: cfg.statusEnabled
        participatingOnly: cfg.participatingOnly
        inboxIntervalSec: cfg.inboxIntervalSec
        searchIntervalSec: cfg.searchIntervalSec
        actionsIntervalSec: cfg.actionsIntervalSec
        watchRepoCount: cfg.watchRepoCount
        repoAllowlist: cfg.repoAllowlist
        mutedRepos: cfg.mutedRepos
        copilotOrg: cfg.copilotOrg

        onMuteRequested: repo => root.mute(repo)
        Component.onCompleted: core.start()
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
            if (!root.activeToken)
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
