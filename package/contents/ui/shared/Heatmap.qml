// Contribution heatmap, drawn in the accent colour rather than GitHub green:
// this sits inside a desktop popup, and a widget that ignores the palette
// looks pasted in.
//
// One Canvas, not 371 Rectangles. The previous implementation built a
// Repeater of Repeaters — a Rectangle, a HoverHandler and an attached ToolTip
// per day of the year, in both frontends — which is roughly 1100 scene-graph
// nodes for a picture that is 371 filled squares, and it was rebuilt from
// scratch every time the Profile tab was opened. Hit-testing is arithmetic
// here instead.
//
// Intensity comes from Contract.calendar(), which cuts its levels at the 90th
// percentile so one enormous merge day cannot flatten the year.
//
// Platform-neutral (see shared/Pill.qml): plain QtQuick driven by `theme`.
import QtQuick

Item {
    id: heat

    required property var theme
    /** Output of Contract.calendar(); null hides the whole thing. */
    property var calendar: null

    property int minCell: 3
    property int maxCell: 14
    property int gap: 2

    /** The day under the pointer, or null — read by the tooltip above us. */
    readonly property var hoveredDay: heat._hover
    property var _hover: null

    readonly property int columns: heat.calendar ? heat.calendar.weeks.length : 0
    // Clamped at both ends: a full year gives ~6 px cells, but a partial range
    // (a new account, or a truncated API response) would otherwise stretch a
    // single week across the whole pane and blow the height up sevenfold.
    readonly property int cell: heat.columns ? Math.max(heat.minCell, Math.min(heat.maxCell, Math.floor((width - (heat.columns - 1) * heat.gap) / heat.columns))) : 0

    visible: heat.calendar !== null && heat.columns > 0
    implicitHeight: heat.visible ? 7 * heat.cell + 6 * heat.gap : 0

    Canvas {
        id: grid

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!heat.calendar)
                return;

            var weeks = heat.calendar.weeks;
            var size = heat.cell;
            var step = size + heat.gap;
            var radius = Math.max(1, Math.round(size / 4));
            var a = heat.theme.accent;
            var empty = heat.theme.track;
            var hovered = heat._hover;

            for (var w = 0; w < weeks.length; w++) {
                for (var d = 0; d < 7; d++) {
                    var day = weeks[w][d];
                    // A missing day is padding at the ends of the range, not a
                    // quiet day — it gets nothing at all.
                    if (!day)
                        continue;
                    ctx.beginPath();
                    grid.roundRect(ctx, w * step, d * step, size, size, radius);
                    ctx.fillStyle = day.level === 0 ? empty : Qt.rgba(a.r, a.g, a.b, 0.18 + 0.205 * day.level);
                    ctx.fill();
                    if (hovered && hovered.date === day.date) {
                        ctx.strokeStyle = heat.theme.text;
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }
                }
            }
        }

        function roundRect(ctx, x, y, w, h, r) {
            var rr = Math.min(r, w / 2, h / 2);
            ctx.moveTo(x + rr, y);
            ctx.arcTo(x + w, y, x + w, y + h, rr);
            ctx.arcTo(x + w, y + h, x, y + h, rr);
            ctx.arcTo(x, y + h, x, y, rr);
            ctx.arcTo(x, y, x + w, y, rr);
            ctx.closePath();
        }
    }

    onCalendarChanged: grid.requestPaint()
    onCellChanged: grid.requestPaint()
    on_HoverChanged: grid.requestPaint()
    Component.onCompleted: grid.requestPaint()

    HoverHandler {
        onPointChanged: {
            if (!hovered || !heat.calendar) {
                heat._hover = null;
                return;
            }
            var step = heat.cell + heat.gap;
            var w = Math.floor(point.position.x / step);
            var d = Math.floor(point.position.y / step);
            if (w < 0 || d < 0 || d > 6 || w >= heat.calendar.weeks.length) {
                heat._hover = null;
                return;
            }
            heat._hover = heat.calendar.weeks[w][d];
        }
        onHoveredChanged: {
            if (!hovered)
                heat._hover = null;
        }
    }
}
