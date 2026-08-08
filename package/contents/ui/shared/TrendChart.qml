// Contributions over the last thirty days.
//
// The heatmap answers "how consistent am I over a year"; this answers "what
// does this month look like", which the grid is too coarse to show.
//
// Platform-neutral (see shared/Pill.qml) — plain Canvas, driven entirely by
// `theme.accent`, so both the Plasma widget and the Quickshell frontend use
// this file unchanged.
import QtQuick

Canvas {
    id: chart

    required property var theme
    /** Output of Contract.calendar().recent — [{ date, count }]. */
    property var series: []

    readonly property int peak: {
        var m = 0;
        for (var i = 0; i < chart.series.length; i++)
            m = Math.max(m, chart.series[i].count);
        return m;
    }

    // Keep the monthly trend useful without forcing the language legend below
    // the fold in the fixed-height popup.
    implicitHeight: 42
    visible: chart.series.length > 1

    onSeriesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPeakChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var n = chart.series.length;
        if (n < 2 || chart.peak <= 0)
            return;

        var pad = 3;
        var h = chart.height - pad * 2;
        var step = chart.width / (n - 1);

        function x(i) {
            return i * step;
        }
        function y(v) {
            return pad + h - (v / chart.peak) * h;
        }

        // Filled area first, so the stroke sits crisply on top of it.
        ctx.beginPath();
        ctx.moveTo(0, chart.height);
        for (var i = 0; i < n; i++)
            ctx.lineTo(x(i), y(chart.series[i].count));
        ctx.lineTo(chart.width, chart.height);
        ctx.closePath();
        var grad = ctx.createLinearGradient(0, 0, 0, chart.height);
        grad.addColorStop(0, Qt.rgba(chart.theme.accent.r, chart.theme.accent.g, chart.theme.accent.b, 0.35));
        grad.addColorStop(1, Qt.rgba(chart.theme.accent.r, chart.theme.accent.g, chart.theme.accent.b, 0));
        ctx.fillStyle = grad;
        ctx.fill();

        ctx.beginPath();
        for (var j = 0; j < n; j++) {
            if (j === 0)
                ctx.moveTo(x(j), y(chart.series[j].count));
            else
                ctx.lineTo(x(j), y(chart.series[j].count));
        }
        ctx.strokeStyle = chart.theme.accent;
        ctx.lineWidth = 1.6;
        ctx.lineJoin = "round";
        ctx.stroke();

        // Mark the most recent day so "today" is findable at a glance.
        ctx.beginPath();
        ctx.arc(x(n - 1), y(chart.series[n - 1].count), 2.6, 0, Math.PI * 2);
        ctx.fillStyle = chart.theme.accent;
        ctx.fill();
    }
}
