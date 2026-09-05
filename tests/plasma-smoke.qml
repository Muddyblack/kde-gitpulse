// Gitpulse — Plasma UI smoke test.
//
//   qml -platform offscreen tests/plasma-smoke.qml      (or: make test)
//
// The Quickshell frontend has had a smoke test since day one; the Plasma one
// had only qmllint, which cannot see a binding that throws at runtime. This
// renders the real PopupView.qml and PanelSlot.qml against the stand-in Plasma
// modules in tests/stubs/, cycles every tab with the same fabricated data the
// Quickshell test uses, and fails on any binding error.
//
// It is not a substitute for looking at it in a real Plasma session — the
// stubs approximate Kirigami rather than implement it — but it does catch the
// class of bug that otherwise reaches someone's panel.
import QtQuick
import QtQuick.Layouts

import "../package/contents/ui" as UI
import "../package/contents/ui/engine" as Core
import "Fixtures.js" as Fixtures
import "I18n.js" as I18n

Item {
    id: harness

    // Plasma's own preferred popup size: gridUnit * 24 by gridUnit * 30.
    readonly property int baseHeight: 540

    width: 432
    height: harness.baseHeight

    readonly property var core: Core.Engine

    // ── the applet, as far as the popup is concerned ────────────────────────
    //
    // PopupView and its panes only ever ask the host for these; main.qml is
    // out of scope here because it needs the notification and process APIs,
    // neither of which belongs in a test.
    QtObject {
        id: fakeHost

        property string currentTab: "inbox"

        readonly property var tabs: [
            {
                id: "inbox",
                label: "Inbox",
                icon: "mail-message"
            },
            {
                id: "actions",
                label: "Actions",
                icon: "media-playback-start"
            },
            {
                id: "pulls",
                label: "Pulls",
                icon: "vcs-merge-request"
            },
            {
                id: "issues",
                label: "Issues",
                icon: "view-task"
            },
            {
                id: "profile",
                label: "Profile",
                icon: "user-identity"
            },
            {
                id: "copilot",
                label: "Copilot",
                icon: "computer"
            },
            {
                id: "status",
                label: "Status",
                icon: "network-server"
            }
        ]

        function openUrl(url) {
        }

        function muteRepo(repo) {
        }

        function cycleTab(delta) {
        }

        function inboxUrl(item) {
            return "";
        }
    }

    /**
     * Pass `--shot <dir>` to also write a PNG per tab. Handy for eyeballing a
     * change without a Plasma session, and for attaching to a pull request.
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
            result.saveToFile(harness.shotDir + "/gitpulse-plasma-" + label + ".png");
        });
    }

    Rectangle {
        anchors.fill: parent
        color: "#1b1e20"
    }

    // Behind a Loader on purpose: `i18n()` has to exist on the JS global
    // before the first binding that calls it is evaluated, and every one of
    // these files calls it. Component.onCompleted on the root runs too late.
    Loader {
        id: popupLoader

        anchors.fill: parent
        active: false

        sourceComponent: UI.PopupView {
            engine: harness.core
            host: fakeHost
        }
    }

    readonly property var popup: popupLoader.item

    // The panel representation, rendered off to the side so a broken compact
    // view is caught too.
    Loader {
        anchors.top: parent.top
        active: popupLoader.active
        opacity: 0

        sourceComponent: UI.PanelSlot {
            width: 120
            height: 26
            engine: harness.core
            host: fakeHost
        }
    }

    readonly property var states: [
        {
            label: "inbox",
            apply: () => fakeHost.currentTab = "inbox"
        },
        {
            label: "actions",
            apply: () => fakeHost.currentTab = "actions"
        },
        {
            label: "pulls",
            apply: () => fakeHost.currentTab = "pulls"
        },
        {
            label: "issues",
            apply: () => fakeHost.currentTab = "issues"
        },
        {
            label: "profile",
            apply: () => fakeHost.currentTab = "profile"
        },
        {
            label: "copilot",
            apply: () => fakeHost.currentTab = "copilot"
        },
        {
            label: "status",
            apply: () => fakeHost.currentTab = "status"
        },
        {
            // The Profile tab scrolls at the default popup height, so this one
            // is rendered tall enough to show the hour dial and the streak
            // figures that live below the fold.
            label: "profile-full",
            height: 900,
            apply: () => fakeHost.currentTab = "profile"
        },
        {
            label: "grouped",
            apply: () => {
                fakeHost.currentTab = "inbox";
                harness.popup.grouped = true;
            }
        },
        {
            label: "search",
            apply: () => {
                harness.popup.grouped = false;
                harness.popup.searchActive = true;
                harness.popup.query = "gitpulse";
            }
        },
        {
            label: "chip-filtered",
            apply: () => {
                harness.popup.searchActive = false;
                harness.popup.query = "";
                harness.popup.setChip("needs");
            }
        }
    ]

    property int step: 0

    Component.onCompleted: {
        I18n.install();
        Fixtures.install(harness.core);
        popupLoader.active = true;
    }

    /**
     * One tick to change state, the next to photograph it.
     *
     * Canvas paints asynchronously — the heatmap, the trend chart and the hour
     * dial are all Canvas — so grabbing in the same tick that switched the tab
     * captured them blank.
     */
    property string pendingShot: ""

    Timer {
        interval: 90
        repeat: true
        running: true
        onTriggered: {
            if (harness.pendingShot !== "") {
                harness.shoot(harness.pendingShot);
                harness.pendingShot = "";
                return;
            }
            if (harness.step >= harness.states.length) {
                running = false;
                console.warn("plasma-smoke: rendered every tab and state");
                Qt.exit(0);
                return;
            }
            var state = harness.states[harness.step];
            harness.height = state.height || harness.baseHeight;
            state.apply();
            harness.pendingShot = state.label;
            harness.step++;
        }
    }
}
