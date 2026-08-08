// Contribution heatmap.
//
// Drawn in the user's accent colour rather than GitHub's green: this sits
// inside a Plasma popup, and a widget that ignores the desktop's palette looks
// pasted in. Intensity comes from Contract.calendar(), which cuts its levels at
// the 90th percentile so one enormous merge day cannot flatten the year.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: graph

    readonly property Tones tones: Tones {}

    /** Output of Contract.calendar(); null while unavailable. */
    required property var calendar

    readonly property int columns: graph.calendar ? graph.calendar.weeks.length : 0
    readonly property int cell: Math.max(4, Math.floor((width - (graph.columns - 1) * gap) / Math.max(1, graph.columns)))
    readonly property int gap: Math.max(1, Math.round(Kirigami.Units.smallSpacing / 2))

    implicitHeight: graph.calendar ? 7 * cell + 6 * gap : 0
    visible: graph.calendar !== null

    Row {
        spacing: graph.gap

        Repeater {
            model: graph.columns

            delegate: Column {
                id: week

                required property int index

                spacing: graph.gap

                Repeater {
                    model: 7

                    delegate: Rectangle {
                        required property int index

                        readonly property var day: graph.calendar.weeks[week.index][index]

                        width: graph.cell
                        height: graph.cell
                        radius: Math.max(1, Math.round(graph.cell / 4))
                        // A missing day is padding at the ends of the range,
                        // not a quiet day — it gets nothing at all.
                        color: !day ? "transparent" : day.level === 0 ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08) : Qt.rgba(graph.tones.accent.r, graph.tones.accent.g, graph.tones.accent.b, 0.18 + 0.205 * day.level)

                        HoverHandler {
                            id: hover
                            enabled: day !== null
                        }

                        PlasmaComponents.ToolTip.visible: hover.hovered
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.text: day ? i18np("%1 contribution on %2", "%1 contributions on %2", day.count, day.date) : ""
                    }
                }
            }
        }
    }
}
