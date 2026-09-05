// When in the day this account commits — a 24-hour dial.
//
// The contribution heatmap answers "which days"; this answers "which hours",
// which is the question the heatmap cannot even represent. One spoke per hour,
// midnight at the top, running clockwise, each spoke as long as that hour is
// busy relative to the busiest one.
//
// The rim doubles as a day/night read: dim over the night hours, lit over the
// daylight ones, so the shape of a night-owl account is legible before you
// read a single tick label.
//
// Platform-neutral (see shared/Pill.qml) — one Canvas, driven entirely by
// `theme`, so the Plasma widget and the Quickshell frontend use this file
// unchanged.
import QtQuick

Item {
    id: dial

    required property var theme
    /** Contract.clock() output — { hours[24], peak, peakHour, total, tz }. */
    property var clock: null

    /** The hour under the pointer, or -1. Read by the caption above us. */
    readonly property int hoverHour: dial._hover
    property int _hover: -1

    /** Local hour, for the hand. Refreshed on the minute, not per frame. */
    property int _nowHour: new Date().getHours()
    property real _nowFraction: new Date().getMinutes() / 60

    readonly property bool ready: dial.clock !== null && dial.clock !== undefined && dial.clock.total > 0

    implicitWidth: 132
    implicitHeight: 132
    visible: dial.ready

    Timer {
        interval: 60000
        repeat: true
        running: dial.visible
        onTriggered: {
            var now = new Date();
            dial._nowHour = now.getHours();
            dial._nowFraction = now.getMinutes() / 60;
        }
    }

    Canvas {
        id: face

        anchors.fill: parent
        // Repainting only on a real change: this sits in a popup that is
        // re-laid-out on every tab switch, and a Canvas that repaints on every
        // geometry tick is the difference between a smooth popup and a warm
        // laptop.
        renderStrategy: Canvas.Cooperative

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real outer: Math.min(width, height) / 2
        readonly property real tickR: face.outer - 7
        readonly property real rim: face.tickR - 11
        readonly property real spokeMax: face.rim - 4
        readonly property real hub: Math.max(3, face.spokeMax * 0.24)

        function rad(hour) {
            return (-90 + hour * 15) * Math.PI / 180;
        }

        /** 0 at 01:00 (deepest night), 1 at 13:00 (peak day). */
        function daylight(h) {
            return (Math.cos((h - 13) / 24 * 2 * Math.PI) + 1) / 2;
        }

        function mix(a, b, t) {
            return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!dial.ready)
                return;

            var hours = dial.clock.hours;
            var peak = dial.clock.peak || 1;
            var night = dial.theme.textDim;
            var day = dial.theme.accent;

            // ── rim: two arcs, no fill, so there is no hard half-disc edge ──
            var arcs = [
                {
                    from: 18,
                    to: 30,
                    color: night,
                    alpha: 0.35
                },
                {
                    from: 6,
                    to: 18,
                    color: day,
                    alpha: 0.5
                }
            ];
            arcs.forEach(function (a) {
                ctx.beginPath();
                ctx.arc(face.cx, face.cy, face.rim, face.rad(a.from), face.rad(a.to));
                ctx.strokeStyle = Qt.rgba(a.color.r, a.color.g, a.color.b, a.alpha);
                ctx.lineWidth = 1.5;
                ctx.lineCap = "round";
                ctx.stroke();
            });

            // ── the hand: where we are in the day right now ─────────────────
            var handAngle = face.rad(dial._nowHour + dial._nowFraction);
            ctx.beginPath();
            ctx.moveTo(face.cx, face.cy);
            ctx.lineTo(face.cx + face.rim * Math.cos(handAngle), face.cy + face.rim * Math.sin(handAngle));
            ctx.strokeStyle = Qt.rgba(day.r, day.g, day.b, 0.22);
            ctx.lineWidth = 1;
            ctx.stroke();

            // ── spokes ─────────────────────────────────────────────────────
            var span = face.spokeMax - face.hub - 2;
            for (var h = 0; h < 24; h++) {
                var angle = face.rad(h);
                // Every hour keeps a short stub, so a quiet hour reads as
                // "quiet" rather than as a gap in the dial.
                var end = face.hub + 2 + (hours[h] / peak) * span;
                var lit = h === dial._hover;
                var c = face.mix(night, day, 0.2 + 0.8 * face.daylight(h));

                ctx.beginPath();
                ctx.moveTo(face.cx + face.hub * Math.cos(angle), face.cy + face.hub * Math.sin(angle));
                ctx.lineTo(face.cx + end * Math.cos(angle), face.cy + end * Math.sin(angle));
                ctx.strokeStyle = lit ? day : Qt.rgba(c.r, c.g, c.b, hours[h] > 0 ? 0.95 : 0.4);
                ctx.lineWidth = lit ? 4.2 : 3.2;
                ctx.lineCap = "round";
                ctx.stroke();
            }

            // ── hub ────────────────────────────────────────────────────────
            ctx.beginPath();
            ctx.arc(face.cx, face.cy, 2.4, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(day.r, day.g, day.b, 0.75);
            ctx.fill();

            // ── ticks ──────────────────────────────────────────────────────
            ctx.font = Math.max(8, dial.theme.smallFontSize - 1) + "px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillStyle = dial.theme.textFaint;
            [0, 6, 12, 18].forEach(function (h) {
                var a = face.rad(h);
                ctx.fillText(("0" + h).slice(-2), face.cx + face.tickR * Math.cos(a), face.cy + face.tickR * Math.sin(a));
            });
        }
    }

    // One repaint per meaningful change, rather than one per binding tick.
    onClockChanged: face.requestPaint()
    on_HoverChanged: face.requestPaint()
    on_NowHourChanged: face.requestPaint()
    onWidthChanged: face.requestPaint()
    onHeightChanged: face.requestPaint()
    Component.onCompleted: face.requestPaint()

    /**
     * Hit-testing by angle rather than by 24 invisible Items: the dial stays
     * one scene-graph node however many hours it draws.
     */
    HoverHandler {
        id: hover

        onPointChanged: {
            if (!hovered) {
                dial._hover = -1;
                return;
            }
            var dx = point.position.x - face.cx;
            var dy = point.position.y - face.cy;
            var r = Math.sqrt(dx * dx + dy * dy);
            if (r < face.hub || r > face.outer) {
                dial._hover = -1;
                return;
            }
            var deg = Math.atan2(dy, dx) * 180 / Math.PI + 90;
            if (deg < 0)
                deg += 360;
            dial._hover = Math.round(deg / 15) % 24;
        }
        onHoveredChanged: {
            if (!hovered)
                dial._hover = -1;
        }
    }
}
