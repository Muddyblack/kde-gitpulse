// One incident, with the updates GitHub posted about it.
//
// The 90-day strips say *when* something broke; this says *what* GitHub told
// people at the time, which is the part you actually want when you are trying
// to work out whether your build failed for a good reason.
import QtQuick
import QtQuick.Layouts

import "../package/contents/ui/shared" as Shared
import "../package/contents/code/Format.js" as Format

Rectangle {
    id: entry

    required property var theme
    required property var incident

    property bool expanded: false

    readonly property string tone: Format.impactTone(entry.incident.impact)
    readonly property bool resolved: entry.incident.status === "resolved" || entry.incident.status === "postmortem"
    readonly property var updates: entry.incident.incident_updates || []

    implicitHeight: body.implicitHeight + entry.theme.spacing
    radius: entry.theme.radiusSmall
    color: hover.hovered ? entry.theme.surfaceAlt : entry.theme.surface
    opacity: entry.resolved && !entry.expanded ? 0.75 : 1

    Behavior on color {
        ColorAnimation {
            duration: entry.theme.shortDuration
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        onClicked: entry.expanded = !entry.expanded
    }

    // Severity spine — faster to read than a coloured background at this size.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        width: 2
        radius: 1
        color: entry.theme.of(entry.tone)
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: entry.theme.spacingSmall * 1.5
        anchors.leftMargin: entry.theme.spacing
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: entry.theme.spacingSmall * 1.5

            Text {
                Layout.fillWidth: true
                text: entry.incident.name || ""
                color: entry.theme.text
                font.pixelSize: 12
                font.weight: entry.resolved ? Font.Normal : Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: entry.expanded ? 4 : 2
                elide: Text.ElideRight
            }

            Icon {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                name: "chevron"
                color: entry.theme.textFaint
                rotation: entry.expanded ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: entry.theme.longDuration
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: entry.theme.spacingSmall * 1.5

            Shared.Pill {
                theme: entry.theme
                text: entry.incident.impact || "unknown"
                tone: entry.tone
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("%1 · %2 ago").arg(Format.humanise(entry.incident.status || "")).arg(Format.relative(entry.incident.updated_at))
                color: entry.theme.textFaint
                font.pixelSize: 10
                font.family: "monospace"
                elide: Text.ElideRight
            }
        }

        // Affected services — the reason you opened this in the first place.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: entry.expanded && text !== ""
            text: (entry.incident.components || []).map(function (c) {
                return c.name;
            }).join(", ")
            color: entry.theme.textDim
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Repeater {
            model: entry.expanded ? entry.updates : []

            delegate: ColumnLayout {
                id: update

                required property var modelData

                Layout.fillWidth: true
                Layout.topMargin: entry.theme.spacingSmall
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: qsTr("%1 · %2 ago").arg(Format.humanise(update.modelData.status || "")).arg(Format.relative(update.modelData.updated_at))
                    color: entry.theme.of(entry.tone)
                    font.pixelSize: 10
                    font.family: "monospace"
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    // GitHub's update bodies are plain text; rendering them as
                    // rich text would let a third party inject markup here.
                    text: update.modelData.body || ""
                    textFormat: Text.PlainText
                    color: entry.theme.textDim
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
