// 90-day incident strip for one service.
//
// Built from githubstatus.com's incident feed — not an uptime percentage,
// which GitHub does not publish. See Contract.incidentStrip().
import QtQuick
import QtQuick.Controls.Basic as QC

Item {
    id: strip

    required property var theme
    property var days: []

    readonly property real cell: strip.days.length ? Math.max(1, (width - (strip.days.length - 1)) / strip.days.length) : 0

    implicitHeight: 10

    Row {
        anchors.fill: parent
        spacing: 1

        Repeater {
            model: strip.days

            delegate: Rectangle {
                required property var modelData

                width: strip.cell
                height: strip.height
                radius: 1
                color: modelData.impact ? strip.theme.of(modelData.tone) : Qt.rgba(strip.theme.positive.r, strip.theme.positive.g, strip.theme.positive.b, 0.3)

                HoverHandler {
                    id: hover
                }

                QC.ToolTip.visible: hover.hovered
                QC.ToolTip.delay: 400
                QC.ToolTip.text: modelData.impact ? modelData.date + " — " + modelData.impact : modelData.date + " — no recorded incident"
            }
        }
    }
}
