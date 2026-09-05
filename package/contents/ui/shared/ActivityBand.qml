// The activity band: when you commit, and how long the streaks run.
//
// Four cells on one line — the hour dial keeps its own, the three figures
// split what is left. They were two separate blocks in two separate
// implementations (a hand-rolled row on the Plasma side, StreakCard.qml on the
// Quickshell side) saying things that are all "activity"; this is one
// component, used by both.
//
// Platform-neutral (see shared/Pill.qml): plain QtQuick driven by `theme`.
import QtQuick
import QtQuick.Layouts

import "../../code/Format.js" as Fmt

ColumnLayout {
    id: band

    required property var theme
    /** Contract.calendar() output; null hides the figures. */
    property var calendar: null
    /** Contract.clock() output; null hides the dial. */
    property var clock: null
    /** Contract.rhythm() output, for the caption when nothing is hovered. */
    property var rhythm: []

    /** Below this the dial and the figures stack instead of sitting side by side. */
    property int wideAt: 320

    readonly property bool wide: band.width >= band.wideAt
    readonly property bool hasClock: band.clock !== null && band.clock !== undefined && band.clock.total > 0
    readonly property bool hasCalendar: band.calendar !== null && band.calendar !== undefined

    /**
     * The line under the dial.
     *
     * Hovering an hour answers "how many, exactly"; otherwise it names the
     * timezone, because a chart of local hours that does not say so is a chart
     * people quietly assume is wrong.
     */
    readonly property string caption: {
        if (!band.hasClock)
            return "";
        var h = clockDial.hoverHour;
        if (h >= 0) {
            var n = band.clock.hours[h];
            return ("0" + h).slice(-2) + ":00 · " + n + (n === 1 ? " commit" : " commits");
        }
        return qsTr("commits by hour · %1").arg(band.clock.tz);
    }

    spacing: band.theme.spacing
    visible: band.hasClock || band.hasCalendar

    GridLayout {
        Layout.fillWidth: true
        columns: band.wide ? 2 : 1
        columnSpacing: band.theme.spacing * 2
        rowSpacing: band.theme.spacing

        // ── the dial ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
            visible: band.hasClock
            spacing: 2

            CommitClock {
                id: clockDial

                theme: band.theme
                clock: band.clock
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 128
                implicitHeight: 128
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 150
                text: band.caption
                color: clockDial.hoverHour >= 0 ? band.theme.accent : band.theme.textFaint
                font.pixelSize: band.theme.smallFontSize
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── the three figures ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: band.hasCalendar
            spacing: 0

            Figure {
                value: band.hasCalendar ? Number(band.calendar.total).toLocaleString(Qt.locale(), "f", 0) : "0"
                label: qsTr("Contributions")
                sub: band.hasCalendar && band.calendar.first ? qsTr("%1 — now").arg(Fmt.shortDate(band.calendar.first)) : ""
                accented: true
            }

            Rule {}

            // The ring is the only decorated number here on purpose: it is the
            // one that changes daily, so it earns the emphasis.
            Figure {
                value: band.hasCalendar ? String(band.calendar.current) : "0"
                label: qsTr("Current streak")
                sub: band.hasCalendar && band.calendar.currentFrom ? qsTr("since %1").arg(Fmt.shortDate(band.calendar.currentFrom)) : ""
                ring: true
                accented: true
            }

            Rule {}

            Figure {
                value: band.hasCalendar ? String(band.calendar.streak) : "0"
                label: qsTr("Longest streak")
                sub: band.hasCalendar && band.calendar.streakSpan && band.calendar.streakSpan[0] ? Fmt.shortDate(band.calendar.streakSpan[0]) + " — " + Fmt.shortDate(band.calendar.streakSpan[1]) : ""
            }
        }
    }

    component Rule: Rectangle {
        Layout.fillHeight: true
        Layout.maximumHeight: 52
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        color: band.theme.line
    }

    component Figure: ColumnLayout {
        id: figure

        property string value: ""
        property string label: ""
        property string sub: ""
        property bool accented: false
        /** Draws the progress ring — current streak against the record. */
        property bool ring: false

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: figure.ring ? 46 : number.implicitWidth
            implicitHeight: figure.ring ? 46 : number.implicitHeight

            Canvas {
                anchors.fill: parent
                visible: figure.ring
                renderStrategy: Canvas.Cooperative

                /** Fraction of the record the current streak has reached. */
                readonly property real progress: band.hasCalendar && band.calendar.streak > 0 ? Math.min(1, band.calendar.current / band.calendar.streak) : 0

                onProgressChanged: requestPaint()
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var r = Math.min(width, height) / 2 - 2;
                    var a = band.theme.accent;
                    ctx.lineWidth = 2.6;
                    ctx.lineCap = "round";

                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                    ctx.strokeStyle = band.theme.track;
                    ctx.stroke();

                    if (progress <= 0)
                        return;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + progress * Math.PI * 2);
                    ctx.strokeStyle = a;
                    ctx.stroke();
                }
            }

            Text {
                id: number

                anchors.centerIn: parent
                text: figure.value
                color: figure.accented ? band.theme.accent : band.theme.text
                font.pixelSize: figure.ring ? 16 : 19
                font.weight: Font.Bold
            }
        }

        Text {
            Layout.fillWidth: true
            text: figure.label
            color: band.theme.textDim
            font.pixelSize: band.theme.smallFontSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: figure.sub
            color: band.theme.textFaint
            font.pixelSize: Math.max(8, band.theme.smallFontSize - 1)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
