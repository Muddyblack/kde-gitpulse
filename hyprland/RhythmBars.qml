// When in the day this account tends to push.
//
// Derived from the public event feed, so it covers roughly the last 90 days of
// public activity — enough for a shape, not a total. Times are local.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: rhythm

    required property var theme
    /** Output of Contract.rhythm() — [{ name, count, share }], busiest first. */
    property var buckets: []

    readonly property real peak: rhythm.buckets.length ? rhythm.buckets[0].share : 0

    spacing: 2
    visible: rhythm.buckets.length > 0

    Repeater {
        model: rhythm.buckets

        delegate: RowLayout {
            id: bar

            required property var modelData

            Layout.fillWidth: true
            spacing: rhythm.theme.spacing

            Text {
                text: bar.modelData.name
                color: rhythm.theme.textDim
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 62
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 7
                radius: 3.5
                color: Qt.rgba(1, 1, 1, 0.07)

                Rectangle {
                    // Scaled against the busiest bucket rather than 100%, so a
                    // flat distribution still reads as a chart.
                    width: rhythm.peak > 0 ? Math.max(height, parent.width * bar.modelData.share / rhythm.peak) : 0
                    height: parent.height
                    radius: 4
                    color: rhythm.theme.accent
                    opacity: 0.45 + 0.55 * (rhythm.peak > 0 ? bar.modelData.share / rhythm.peak : 0)

                    Behavior on width {
                        NumberAnimation {
                            duration: rhythm.theme.longDuration
                        }
                    }
                }
            }

            Text {
                text: Math.round(bar.modelData.share) + "%"
                color: rhythm.theme.textFaint
                font.pixelSize: 10
                font.family: "monospace"
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 28
            }
        }
    }
}
