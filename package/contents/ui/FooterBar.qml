// Popup footer: how fresh the data is, how much budget is left, and the one
// bulk action.
//
// Freshness is permanent furniture rather than a transient toast, because
// "is this current?" is a question every glance at the list implicitly asks.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

PlasmaExtras.PlasmoidHeading {
    id: footer

    required property var engine
    signal markAllRead

    position: PlasmaExtras.PlasmoidHeading.Position.Footer

    /** Re-evaluates the relative timestamp without polling anything. */
    property int tick: 0

    Timer {
        interval: 10000
        repeat: true
        running: footer.visible
        onTriggered: footer.tick++
    }

    readonly property string freshness: {
        if (footer.tick < 0)
            return "";
        switch (footer.engine.primaryError) {
        case GH.ERR.NO_TOKEN:
            return i18n("not configured");
        case GH.ERR.OFFLINE:
            return footer.engine.lastUpdateMs > 0 ? i18n("offline · cache %1 old", Fmt.relative(new Date(footer.engine.lastUpdateMs).toISOString())) : i18n("offline");
        case GH.ERR.RATE_LIMIT:
            return i18n("paused · last %1 ago", Fmt.relative(new Date(footer.engine.lastUpdateMs).toISOString()));
        }
        if (footer.engine.lastUpdateMs === 0)
            return i18n("waiting for first sync");
        return i18n("updated %1 ago", Fmt.relative(new Date(footer.engine.lastUpdateMs).toISOString()));
    }

    readonly property string freshTone: {
        switch (footer.engine.primaryError) {
        case GH.ERR.OFFLINE:
        case GH.ERR.AUTH:
            return "negative";
        case GH.ERR.RATE_LIMIT:
        case GH.ERR.NO_TOKEN:
            return "neutral";
        default:
            return "positive";
        }
    }

    readonly property Tones tones: Tones {}

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.smallSpacing * 1.5
            implicitHeight: implicitWidth
            radius: width / 2
            color: footer.tones.of(footer.freshTone)
        }

        PlasmaComponents.Label {
            text: footer.freshness
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Rate meter — the one number that explains why polling is or is not
        // keeping up. Hidden until GitHub has actually told us a limit.
        RowLayout {
            visible: footer.engine.rateLimit > 0
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolTip.text: i18n("%1 of %2 GitHub API requests left this hour", footer.engine.rateRemaining, footer.engine.rateLimit)
            PlasmaComponents.ToolTip.visible: meterHover.hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

            HoverHandler {
                id: meterHover
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Kirigami.Units.gridUnit * 2
                implicitHeight: Math.max(3, Math.round(Kirigami.Units.smallSpacing * 0.9))
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

                Rectangle {
                    readonly property real frac: footer.engine.rateLimit > 0 ? Math.max(0, footer.engine.rateRemaining) / footer.engine.rateLimit : 0

                    width: Math.max(parent.height, parent.width * frac)
                    height: parent.height
                    radius: parent.radius
                    color: frac <= 0.02 ? footer.tones.negative : frac < 0.25 ? footer.tones.neutral : footer.tones.positive

                    Behavior on width {
                        NumberAnimation {
                            duration: Kirigami.Units.longDuration
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                text: Fmt.compact(footer.engine.rateRemaining)
                font.family: "monospace"
                font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.95)
                color: Kirigami.Theme.disabledTextColor
            }
        }

        PlasmaComponents.ToolButton {
            icon.name: "mail-mark-read"
            text: i18n("Mark all read")
            display: PlasmaComponents.AbstractButton.TextBesideIcon
            enabled: footer.engine.badge.unread > 0
            onClicked: footer.markAllRead()

            PlasmaComponents.ToolTip.text: i18n("Mark all notifications as read  ( Shift+M )")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }
}
