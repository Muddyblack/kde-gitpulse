// Gitpulse — Plasma 6 applet.
//
// This file is only the Plasma integration layer: configuration in, applet
// status and representations out. All GitHub behaviour lives in Engine.qml and
// the shared JS, which the Quickshell frontend reuses unchanged.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.notification
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH
import "engine" as EngineNS

PlasmoidItem {
    id: root

    // ── which tab the popup is showing ──────────────────────────────────────
    property string currentTab: Plasmoid.configuration.defaultTab || "inbox"

    readonly property var tabs: {
        var t = [
            {
                id: "inbox",
                label: i18n("Inbox"),
                icon: "mail-message"
            }
        ];
        if (Plasmoid.configuration.actionsEnabled)
            t.push({
                id: "actions",
                label: i18n("Actions"),
                icon: "media-playback-start"
            });
        if (Plasmoid.configuration.pullsEnabled)
            t.push({
                id: "pulls",
                label: i18n("Pulls"),
                icon: "vcs-merge-request"
            });
        if (Plasmoid.configuration.issuesEnabled)
            t.push({
                id: "issues",
                label: i18n("Issues"),
                icon: "view-task"
            });
        if (Plasmoid.configuration.profileEnabled)
            t.push({
                id: "profile",
                label: i18n("Profile"),
                icon: "user-identity"
            });
        if (Plasmoid.configuration.copilotEnabled)
            t.push({
                id: "copilot",
                label: i18n("Copilot"),
                icon: "computer"
            });
        if (Plasmoid.configuration.statusEnabled)
            t.push({
                id: "status",
                label: i18n("Status"),
                icon: "network-server"
            });
        return t;
    }

    function cycleTab(delta) {
        var ids = root.tabs.map(function (t) {
            return t.id;
        });
        var i = ids.indexOf(root.currentTab);
        if (i < 0)
            i = 0;
        root.currentTab = ids[(i + delta + ids.length) % ids.length];
    }

    function openUrl(url) {
        if (url)
            Qt.openUrlExternally(url);
    }

    /** The engine cannot persist anything; configuration is the applet's job. */
    function muteRepo(repo) {
        var list = String(Plasmoid.configuration.mutedRepos || "").split(",").map(function (s) {
            return s.trim();
        }).filter(function (s) {
            return s.length > 0;
        });
        if (list.indexOf(repo) < 0)
            list.push(repo);
        Plasmoid.configuration.mutedRepos = list.join(", ");
    }

    // ── credentials ─────────────────────────────────────────────────────────
    readonly property GhToken gh: GhToken {
        enabled: Plasmoid.configuration.useGhCli
    }
    readonly property string activeToken: Plasmoid.configuration.useGhCli ? root.gh.token : Plasmoid.configuration.token

    // ── engine ──────────────────────────────────────────────────────────────
    //
    // Shared singleton (engine/Engine.qml + engine/qmldir): every placement of
    // this applet in this process — one per monitor is the common case for
    // this collection's per-screen panels — binds to the same object, so
    // there is exactly one poller against GitHub no matter how many panels
    // show it, instead of one independent poller (and one avatar/API fetch
    // set) per placement.
    readonly property var engine: EngineNS.Engine

    Binding {
        target: root.engine
        property: "token"
        value: root.activeToken
    }
    Binding {
        target: root.engine
        property: "graphqlToken"
        value: Plasmoid.configuration.graphqlToken
    }
    Binding {
        target: root.engine
        property: "active"
        value: true
    }
    Binding {
        target: root.engine
        property: "inboxIntervalSec"
        value: Plasmoid.configuration.inboxIntervalSec
    }
    Binding {
        target: root.engine
        property: "searchIntervalSec"
        value: Plasmoid.configuration.searchIntervalSec
    }
    Binding {
        target: root.engine
        property: "actionsIntervalSec"
        value: Plasmoid.configuration.actionsIntervalSec
    }
    Binding {
        target: root.engine
        property: "profileIntervalSec"
        value: Plasmoid.configuration.profileIntervalSec
    }
    Binding {
        target: root.engine
        property: "statusIntervalSec"
        value: Plasmoid.configuration.statusIntervalSec
    }
    Binding {
        target: root.engine
        property: "watchRepoCount"
        value: Plasmoid.configuration.watchRepoCount
    }
    Binding {
        target: root.engine
        property: "includeOrgRepos"
        value: Plasmoid.configuration.includeOrgRepos
    }
    Binding {
        target: root.engine
        property: "repoAllowlist"
        value: Plasmoid.configuration.repoAllowlist
    }
    Binding {
        target: root.engine
        property: "mutedRepos"
        value: Plasmoid.configuration.mutedRepos
    }
    Binding {
        target: root.engine
        property: "participatingOnly"
        value: Plasmoid.configuration.participatingOnly
    }
    Binding {
        target: root.engine
        property: "includeRead"
        value: Plasmoid.configuration.includeRead
    }
    Binding {
        target: root.engine
        property: "copilotOrg"
        value: Plasmoid.configuration.copilotOrg
    }
    Binding {
        target: root.engine
        property: "actionsEnabled"
        value: Plasmoid.configuration.actionsEnabled
    }
    Binding {
        target: root.engine
        property: "pullsEnabled"
        value: Plasmoid.configuration.pullsEnabled
    }
    Binding {
        target: root.engine
        property: "issuesEnabled"
        value: Plasmoid.configuration.issuesEnabled
    }
    Binding {
        target: root.engine
        property: "profileEnabled"
        value: Plasmoid.configuration.profileEnabled
    }
    Binding {
        target: root.engine
        property: "copilotEnabled"
        value: Plasmoid.configuration.copilotEnabled
    }
    Binding {
        target: root.engine
        property: "statusEnabled"
        value: Plasmoid.configuration.statusEnabled
    }

    // Only the instance that wins ownership reacts to shared-engine signals —
    // see Engine.qml's claimOwner()/releaseOwner() for why.
    readonly property bool notifyOwner: EngineNS.Engine.claimOwner(root)

    Component.onDestruction: EngineNS.Engine.releaseOwner(root)

    Connections {
        target: root.engine
        enabled: root.notifyOwner

        function onArrived(items) {
            root.announce(items);
        }
        function onMuteRequested(repo) {
            root.muteRepo(repo);
        }
    }

    // ── applet status ───────────────────────────────────────────────────────
    //
    // The whole point of being a plasmoid: with nothing to report the icon
    // folds into the tray overflow instead of sitting there showing a zero.
    Plasmoid.status: {
        if (root.activeToken === "")
            return PlasmaCore.Types.ActiveStatus;
        if (root.engine.badge.needsYou > 0)
            return PlasmaCore.Types.NeedsAttentionStatus;
        if (root.engine.badge.tracked > 0 || root.engine.primaryError !== "")
            return PlasmaCore.Types.ActiveStatus;
        return PlasmaCore.Types.PassiveStatus;
    }

    Plasmoid.busy: root.engine.busy && !root.engine.everLoaded

    // "translucent" uses Plasma's own translucent dialog background, which KWin
    // already blurs — the most native frosting available. "glass" paints its
    // own card, so Plasma's background steps aside and only the shadow remains.
    Plasmoid.backgroundHints: {
        switch (Plasmoid.configuration.surfaceMode) {
        case "translucent":
            return PlasmaCore.Types.TranslucentBackground;
        case "glass":
            return PlasmaCore.Types.ShadowBackground;
        default:
            return PlasmaCore.Types.DefaultBackground;
        }
    }

    // Plasma's own "this widget needs setting up" affordance, already
    // translated and already wired to the config dialog. Plasma 6 exposes only
    // the flag to QML — the accompanying sentence is the popup banner's job.
    Plasmoid.configurationRequired: root.activeToken === ""

    toolTipMainText: i18n("Gitpulse")
    toolTipSubText: root.engine.badge.needsYou > 0 ? i18np("%1 item needs you", "%1 items need you", root.engine.badge.needsYou) : i18n("Nothing needs you")

    toolTipItem: TrayTooltip {
        engine: root.engine
    }

    // ── representations ─────────────────────────────────────────────────────
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical ? compactRepresentation : fullRepresentation

    compactRepresentation: PanelSlot {
        engine: root.engine
        host: root
    }

    fullRepresentation: PopupView {
        engine: root.engine
        host: root
    }

    switchWidth: Kirigami.Units.gridUnit * 18
    switchHeight: Kirigami.Units.gridUnit * 18

    // ── applet menu ─────────────────────────────────────────────────────────
    //
    // Zero UI cost: these only exist for people who go looking for them, and
    // Plasma merges them with its own entries.
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh Now")
            icon.name: "view-refresh"
            onTriggered: root.engine.refreshAll(true)
        },
        PlasmaCore.Action {
            text: i18n("Mark All as Read")
            icon.name: "mail-mark-read"
            enabled: root.engine.badge.unread > 0
            onTriggered: root.engine.markAllRead(null)
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("Open Notifications…")
            icon.name: "internet-services"
            onTriggered: root.openUrl(GH.notificationsUrl())
        }
    ]

    // ── desktop notifications ───────────────────────────────────────────────
    //
    // Fire the event and stop. Sound, popup-versus-tray, Do Not Disturb and
    // history are all System Settings ▸ Notifications' job, which is where
    // users already look for them.
    function announce(items) {
        if (!Plasmoid.configuration.notifyEnabled || !items.length)
            return;
        if (items.length === 1) {
            notifier.title = i18n("%1 · %2", items[0].repo, Fmt.reasonLabel(items[0].reason) || items[0].label);
            notifier.text = items[0].title;
            notifier.pendingUrl = items[0].url;
        } else {
            notifier.title = i18np("%1 new item needs you", "%1 new items need you", items.length);
            notifier.text = items.slice(0, 3).map(function (i) {
                return i.repo + " — " + i.title;
            }).join("\n");
            notifier.pendingUrl = GH.notificationsUrl();
        }
        notifier.sendEvent();
    }

    Notification {
        id: notifier

        property string pendingUrl: ""

        componentName: "plasma_workspace"
        eventId: "notification"
        iconName: "org.muddyblack.gitpulse"
        urgency: Notification.NormalUrgency

        defaultAction: NotificationAction {
            label: i18n("Open")
            onActivated: root.openUrl(notifier.pendingUrl)
        }
    }

    Component.onCompleted: root.engine.start()
}
