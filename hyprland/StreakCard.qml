// Total · current streak · longest, the three numbers people actually quote.
//
// The ring around the current streak is the only decorated number here on
// purpose: it is the one that changes daily, so it earns the emphasis.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property var theme
    required property var calendar
    property bool compact: false

    /** Fraction of the record the current streak has reached. */
    readonly property real progress: card.calendar && card.calendar.streak > 0 ? Math.min(1, card.calendar.current / card.calendar.streak) : 0

    implicitHeight: card.compact ? 38 : 92
    radius: card.theme.radiusSmall
    color: card.theme.surface

    RowLayout {
        visible: !card.compact
        anchors.fill: parent
        anchors.margins: card.theme.spacing
        spacing: 0

        // ── total ───────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: card.calendar ? card.calendar.total.toLocaleString(Qt.locale(), "f", 0) : "0"
                color: card.theme.accent
                font.pixelSize: 22
                font.weight: Font.Bold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("contributions")
                color: card.theme.textDim
                font.pixelSize: 10
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("last 12 months")
                color: card.theme.textFaint
                font.pixelSize: 9
            }
        }

        // ── current streak ──────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 46
                implicitHeight: 46

                Canvas {
                    id: ring

                    anchors.fill: parent

                    readonly property real frac: card.progress
                    readonly property color ink: card.theme.accent
                    readonly property color track: card.theme.lineStrong

                    onFracChanged: requestPaint()
                    onInkChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        var r = width / 2 - 3;
                        ctx.reset();
                        ctx.lineWidth = 3;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = ring.track;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                        ctx.stroke();
                        if (ring.frac <= 0)
                            return;
                        ctx.strokeStyle = ring.ink;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ring.frac);
                        ctx.stroke();
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: card.calendar ? card.calendar.current : "0"
                    color: card.theme.text
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("day streak")
                color: card.theme.accent
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        // ── longest ─────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: card.calendar ? card.calendar.streak : "0"
                color: card.theme.text
                font.pixelSize: 22
                font.weight: Font.Bold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("longest streak")
                color: card.theme.textDim
                font.pixelSize: 10
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: card.calendar && card.calendar.busiest > 0 ? qsTr("best day %1").arg(card.calendar.busiest) : ""
                color: card.theme.textFaint
                font.pixelSize: 9
            }
        }
    }

    // The profile pane already has a dense header at normal popup widths.
    // This version preserves the three useful contribution figures without
    // spending a card's worth of vertical space.
    RowLayout {
        visible: card.compact
        anchors.fill: parent
        anchors.leftMargin: card.theme.spacing
        anchors.rightMargin: card.theme.spacing
        spacing: card.theme.spacing

        Repeater {
            model: [
                {
                    value: card.calendar ? card.calendar.total.toLocaleString(Qt.locale(), "f", 0) : "0",
                    label: qsTr("contributions"),
                    color: card.theme.accent
                },
                {
                    value: card.calendar ? card.calendar.current : "0",
                    label: qsTr("day streak"),
                    color: card.theme.text
                },
                {
                    value: card.calendar ? card.calendar.streak : "0",
                    label: qsTr("longest streak"),
                    color: card.theme.text
                }
            ]

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: parent.modelData.value
                    color: parent.modelData.color
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                Text {
                    Layout.fillWidth: true
                    text: parent.modelData.label
                    color: card.theme.textDim
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}
