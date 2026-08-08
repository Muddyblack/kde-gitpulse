// A 90-day bar per service.
//
// Built from githubstatus.com's public incident feed, which is not the same
// thing as GitHub's own uptime percentage — that series is not published. The
// caption says "incident-free days" for exactly that reason: a number that
// looked like an SLA but was not one would be worse than no number.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: uptime

    /** Output of Contract.incidentStrip(). */
    property var strip: []

    readonly property Tones tones: Tones {}
    readonly property int gap: 1
    readonly property real cell: uptime.strip.length ? Math.max(1, (width - (uptime.strip.length - 1) * gap) / uptime.strip.length) : 0

    implicitHeight: uptime.strip.length ? Math.round(Kirigami.Units.gridUnit * 0.7) : 0

    Row {
        anchors.fill: parent
        spacing: uptime.gap

        Repeater {
            model: uptime.strip

            delegate: Rectangle {
                required property var modelData

                width: uptime.cell
                height: uptime.height
                radius: Math.min(1.5, width / 2)
                color: modelData.impact ? uptime.tones.of(modelData.tone) : Qt.rgba(uptime.tones.positive.r, uptime.tones.positive.g, uptime.tones.positive.b, 0.35)

                HoverHandler {
                    id: hover
                }

                PlasmaComponents.ToolTip.visible: hover.hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.text: modelData.impact ? i18nc("date and incident severity", "%1 — %2 incident", modelData.date, modelData.impact) : i18nc("date with no incident", "%1 — no recorded incident", modelData.date)
            }
        }
    }
}
