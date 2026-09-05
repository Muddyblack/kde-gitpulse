// Gitpulse — Quickshell UI smoke test.
//
//   qml -platform offscreen tests/hyprland-smoke.qml     (or: make test)
//
// Renders the whole Hyprland popup with fabricated data and cycles every tab
// and both row states. Every pane here is plain QtQuick, so none of it needs a
// running compositor — only GitpulseShell.qml itself pulls in Quickshell.
//
// The point is to surface binding errors (TypeError, ReferenceError, "Unable
// to assign") in CI instead of in someone's session. The runner greps stderr,
// so anything QML complains about fails the build.
import QtQuick
import "../hyprland" as H
import "../package/contents/ui/engine" as Core
import "../package/contents/code/Contract.js" as Contract
import "Fixtures.js" as Fixtures

Item {
    id: harness

    width: 440
    height: 620

    readonly property var tabs: [
        {
            id: "inbox",
            label: "Inbox"
        },
        {
            id: "actions",
            label: "Actions"
        },
        {
            id: "pulls",
            label: "Pulls"
        },
        {
            id: "issues",
            label: "Issues"
        },
        {
            id: "profile",
            label: "Profile"
        },
        {
            id: "copilot",
            label: "Copilot"
        },
        {
            id: "status",
            label: "Status"
        }
    ]

    property int step: 0

    /**
     * Pass `--shot <dir>` to also write a PNG per tab. Handy for eyeballing a
     * change without a compositor, and for attaching to a pull request.
     */
    readonly property string shotDir: {
        var a = Qt.application.arguments;
        var i = a.indexOf("--shot");
        return i >= 0 && i + 1 < a.length ? a[i + 1] : "";
    }

    function shoot(label) {
        if (harness.shotDir === "")
            return;
        harness.grabToImage(function (result) {
            result.saveToFile(harness.shotDir + "/gitpulse-hyprland-" + label + ".png");
        });
    }

    H.Theme {
        id: ui
    }

    // The real shell paints this; without it the translucent surfaces composite
    // onto white and every screenshot comes out washed out.
    Rectangle {
        anchors.fill: parent
        color: ui.ink
    }

    readonly property var core: Core.Engine

    H.PopupChrome {
        id: chrome

        anchors.fill: parent
        theme: ui
        engine: core
        tabs: harness.tabs
        currentTab: "inbox"
        settingsVisible: false
    }

    H.SettingsPage {
        anchors.fill: parent
        visible: false
        theme: ui
        settings: fakeSettings
    }

    QtObject {
        id: fakeSettings

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
        property string mutedRepos: "muddyblack/noisy"
        property string accent: "#3daee9"
        property real backgroundOpacity: 0.85
        property bool glass: true
    }

    function fabricate() {
        Fixtures.install(harness.core);
    }

    Component.onCompleted: harness.fabricate()

    /** Every state worth rendering, in order. */
    readonly property var states: [
        {
            label: "inbox",
            apply: () => chrome.currentTab = "inbox"
        },
        {
            label: "actions",
            apply: () => chrome.currentTab = "actions"
        },
        {
            label: "pulls",
            apply: () => chrome.currentTab = "pulls"
        },
        {
            label: "issues",
            apply: () => chrome.currentTab = "issues"
        },
        {
            label: "profile",
            apply: () => chrome.currentTab = "profile"
        },
        {
            label: "copilot",
            apply: () => chrome.currentTab = "copilot"
        },
        {
            label: "status",
            apply: () => chrome.currentTab = "status"
        },
        {
            label: "inbox-expanded",
            apply: () => {
                chrome.currentTab = "inbox";
                chrome.expandedId = core.sections.inbox[0].id;
            }
        },
        {
            label: "actions-expanded",
            apply: () => {
                chrome.currentTab = "actions";
                chrome.expandedId = core.sections.actions[1].id;   // the running one
            }
        },
        {
            label: "search",
            apply: () => {
                chrome.expandedId = "";
                chrome.currentTab = "inbox";
                chrome.searchActive = true;
                chrome.query = "review";
            }
        },
        {
            label: "grouped",
            apply: () => {
                chrome.query = "";
                chrome.searchActive = false;
                chrome.grouped = true;
            }
        },
        {
            label: "chip-filtered",
            apply: () => {
                chrome.grouped = false;
                chrome.currentTab = "actions";
                chrome.setChip("failed");
            }
        }
    ]

    // Two ticks per state: one to apply and render it, one to grab it.
    // grabToImage is asynchronous, so grabbing and mutating in the same tick
    // captures the state that comes next.
    Timer {
        interval: 90
        repeat: true
        running: true

        property bool pendingGrab: false

        onTriggered: {
            if (pendingGrab) {
                harness.shoot(harness.states[harness.step].label);
                pendingGrab = false;
                harness.step++;
                return;
            }
            if (harness.step >= harness.states.length) {
                console.warn("hyprland-smoke: rendered every tab and state");
                Qt.exit(0);
                return;
            }
            harness.states[harness.step].apply();
            pendingGrab = true;
        }
    }
}
