// Popup header: who you are, what needs you, and four tools.
//
// Anything rarer than these four lives in the applet's right-click menu, which
// costs no space at all.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/GitHub.js" as GH

PlasmaExtras.PlasmoidHeading {
    id: header

    required property var engine
    property bool searchActive: false
    property bool grouped: false

    signal toggleSearch
    signal toggleGroup
    signal refresh
    signal configure

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2

        Avatar {
            login: header.engine.viewerLogin
            source: header.engine.avatarSource || header.engine.avatarUrl
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            PlasmaExtras.Heading {
                level: 5
                text: i18n("Gitpulse")
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                text: header.summary
            }
        }

        // ── toolbar ─────────────────────────────────────────────────────────
        PlasmaComponents.ToolButton {
            icon.name: "search"
            checkable: true
            checked: header.searchActive
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Filter")
            onClicked: header.toggleSearch()

            PlasmaComponents.ToolTip.text: i18n("Filter  ( / )")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        PlasmaComponents.ToolButton {
            icon.name: "view-list-tree"
            checkable: true
            checked: header.grouped
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Group by repository")
            onClicked: header.toggleGroup()

            PlasmaComponents.ToolTip.text: i18n("Group by repository  ( G )")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        PlasmaComponents.ToolButton {
            // The icon is swapped out rather than spun: a ToolButton's icon is
            // a grouped property with no rotation of its own, and a spinner is
            // the clearer signal anyway.
            icon.name: header.engine.busy ? "" : "view-refresh"
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Refresh")
            enabled: !header.engine.busy
            onClicked: header.refresh()

            PlasmaComponents.ToolTip.text: i18n("Refresh now  ( R )")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

            PlasmaComponents.BusyIndicator {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                running: header.engine.busy
                visible: running
            }
        }

        PlasmaComponents.ToolButton {
            icon.name: "configure"
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Configure…")
            onClicked: header.configure()

            PlasmaComponents.ToolTip.text: i18n("Configure Gitpulse…")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    readonly property string summary: {
        switch (header.engine.primaryError) {
        case GH.ERR.NO_TOKEN:
            return i18n("Not configured");
        case GH.ERR.AUTH:
            return i18n("Token rejected");
        case GH.ERR.RATE_LIMIT:
            return i18n("Rate limited");
        case GH.ERR.OFFLINE:
            return i18n("Offline");
        }
        var b = header.engine.badge;
        var who = header.engine.viewerLogin;
        if (b.needsYou === 0)
            return who ? i18n("%1 · nothing needs you", who) : i18n("Nothing needs you");
        var extra = Math.max(0, b.unread - b.perTab.inbox);
        var core = i18np("%1 needs you", "%1 need you", b.needsYou);
        return extra > 0 ? i18n("%1 · %2 · %3 more unread", who, core, extra) : i18n("%1 · %2", who, core);
    }
}
