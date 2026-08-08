// An open GitHub incident, with its two most recent updates.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/Format.js" as Fmt

Rectangle {
    id: card

    required property var incident

    readonly property Tones tones: Tones {}
    readonly property string tone: Fmt.impactTone(card.incident.impact)
    readonly property var updates: (card.incident.incident_updates || []).slice(0, 2)

    implicitHeight: body.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Kirigami.Theme.alternateBackgroundColor

    // A severity spine reads faster than a coloured background at this size.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
        radius: width / 2
        color: card.tones.of(card.tone)
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        spacing: Math.round(Kirigami.Units.smallSpacing / 2)

        PlasmaComponents.Label {
            text: card.incident.name || ""
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Pill {
                text: card.incident.impact || "unknown"
                tone: card.tone
            }

            PlasmaComponents.Label {
                text: Fmt.humanise(card.incident.status || "")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                text: i18n("%1 ago", Fmt.relative(card.incident.updated_at))
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: card.updates

            delegate: ColumnLayout {
                required property var modelData

                spacing: 0
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: i18nc("incident update state and age", "%1 · %2 ago", Fmt.humanise(parent.modelData.status || ""), Fmt.relative(parent.modelData.updated_at))
                    font.family: "monospace"
                    font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.9)
                    color: Kirigami.Theme.disabledTextColor
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    // GitHub's update bodies are plain text; rendering them as
                    // rich text would let a third party inject markup here.
                    text: parent.modelData.body || ""
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
