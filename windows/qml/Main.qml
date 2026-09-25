// Windows host for the shared Hyprland UI and forge engine.
import QtQuick
import "../../tests/Fixtures.js" as Fixtures
import "../../hyprland"
import "../../package/contents/ui/engine" as EngineNS
import "../../package/contents/code/Forge.js" as Forge

Window {
    id: root
    width: 440
    height: 620
    visible: false
    title: "GitPulse"
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    onPopupVisibleChanged: visible = popupVisible
    onVisibleChanged: popupVisible = visible
    readonly property string iconDir: Qt.resolvedUrl("../../package/contents/icons/")
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
     * The host writes the settings on each change, so the legacy keys are
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

    QtObject {
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
        property bool showUserAvatars: true
    }
    readonly property var core: EngineNS.Engine
    Binding {
        target: root.core
        property: "active"
        value: !backend.selftest
    }

    Binding {
        target: root.core
        property: "accountsJson"
        value: cfg.accounts
    }
    Binding {
        target: root.core
        property: "cliToken"
        value: backend.cliToken
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
    Binding {
        target: root.core
        property: "showUserAvatars"
        value: cfg.showUserAvatars
    }

    Connections {
        target: root.core
        function onMuteRequested(repo) {
            root.mute(repo);
        }
    }

    readonly property bool cliEnabled: accounts.some(a => a.useCli)
    onCliEnabledChanged: backend.setCliEnabled(cliEnabled)
    property bool loaded: false
    property string serializedSettings: JSON.stringify({
        accounts: cfg.accounts,
        token: cfg.token,
        graphqlToken: cfg.graphqlToken,
        useGhCli: cfg.useGhCli,
        quietHoursEnabled: cfg.quietHoursEnabled,
        quietFromHour: cfg.quietFromHour,
        quietToHour: cfg.quietToHour,
        actionsEnabled: cfg.actionsEnabled,
        pullsEnabled: cfg.pullsEnabled,
        issuesEnabled: cfg.issuesEnabled,
        profileEnabled: cfg.profileEnabled,
        copilotEnabled: cfg.copilotEnabled,
        statusEnabled: cfg.statusEnabled,
        participatingOnly: cfg.participatingOnly,
        inboxIntervalSec: cfg.inboxIntervalSec,
        searchIntervalSec: cfg.searchIntervalSec,
        actionsIntervalSec: cfg.actionsIntervalSec,
        watchRepoCount: cfg.watchRepoCount,
        repoAllowlist: cfg.repoAllowlist,
        mutedRepos: cfg.mutedRepos,
        copilotOrg: cfg.copilotOrg,
        accent: cfg.accent,
        backgroundOpacity: cfg.backgroundOpacity,
        glass: cfg.glass,
        showUserAvatars: cfg.showUserAvatars
    })
    onSerializedSettingsChanged: {
        if (loaded)
            saveTimer.restart();
    }
    Timer {
        id: saveTimer
        interval: 250
        onTriggered: root.saveSettings()
    }
    function saveSettings() {
        if (loaded)
            backend.saveSettings(serializedSettings);
    }
    function refresh() {
        backend.refreshCli();
        core.refreshAll(false);
    }
    function openSettings() {
        settingsVisible = true;
        popupVisible = true;
    }
    function smokeStep(index) {
        if (index < tabs.length) {
            settingsVisible = false;
            currentTab = tabs[index].id;
        } else {
            settingsVisible = true;
            settingsPage.section = index === tabs.length ? "settings" : "info";
        }
    }
    readonly property int smokeSteps: tabs.length + 2
    readonly property string traySummary: !core.configured ? qsTr("GitPulse — not configured") : qsTr("GitPulse — %1 need you").arg(core.badge.needsYou)
    onTraySummaryChanged: backend.setSummary(traySummary)
    Component.onCompleted: {
        var saved = JSON.parse(backend.loadSettings());
        for (var key in saved) {
            if (Object.prototype.hasOwnProperty.call(JSON.parse(serializedSettings), key) && typeof saved[key] === typeof cfg[key])
                cfg[key] = saved[key];
        }
        migrateLegacyConfig();
        settingsPage.load();
        loaded = true;
        if (!backend.selftest)
            core.start();
        else {
            cfg.copilotEnabled = true;
            cfg.showUserAvatars = false;
            Fixtures.install(core);
        }
    }
    Shortcut {
        sequence: "Escape"
        onActivated: root.popupVisible = false
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
            id: settingsPage
            anchors.fill: parent
            anchors.margins: ui.spacing * 1.5
            visible: root.settingsVisible

            shell: root
            theme: ui
            settings: cfg
            ghState: backend.cliState
            onClosed: root.settingsVisible = false
        }
    }
}
