// Contribution heatmap, drawn in the shell's accent rather than GitHub green.
import QtQuick
import QtQuick.Controls.Basic as QC

Item {
    id: heat

    required property var theme
    /** Output of Contract.calendar(); null hides the whole thing. */
    property var calendar: null

    readonly property int columns: heat.calendar ? heat.calendar.weeks.length : 0
    readonly property int gap: 2
    // Clamped at both ends: a full year gives ~6 px cells, but a partial range
    // (a new account, or a truncated API response) would otherwise stretch a
    // single week across the whole pane and blow the height up sevenfold.
    readonly property int cell: heat.columns ? Math.max(3, Math.min(14, Math.floor((width - (heat.columns - 1) * gap) / heat.columns))) : 0

    visible: heat.calendar !== null
    implicitHeight: heat.calendar ? 7 * cell + 6 * gap : 0

    Row {
        spacing: heat.gap

        Repeater {
            model: heat.columns

            delegate: Column {
                id: week

                required property int index

                spacing: heat.gap

                Repeater {
                    model: 7

                    delegate: Rectangle {
                        required property int index

                        readonly property var day: heat.calendar.weeks[week.index][index]

                        width: heat.cell
                        height: heat.cell
                        radius: 2
                        color: !day ? "transparent" : day.level === 0 ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(heat.theme.accent.r, heat.theme.accent.g, heat.theme.accent.b, 0.2 + 0.2 * day.level)

                        HoverHandler {
                            id: hover

                            enabled: day !== null
                        }

                        QC.ToolTip.visible: hover.hovered
                        QC.ToolTip.delay: 400
                        QC.ToolTip.text: day ? day.count + " on " + day.date : ""
                    }
                }
            }
        }
    }
}
