// A GitHub incident. The history tab expands it to show every update.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

import "../code/Format.js" as Fmt

Rectangle {
    id: card

    required property var incident
    property bool expandable: false
    property bool expanded: false

    readonly property Tones tones: Tones {}
    readonly property string tone: Fmt.impactTone(card.incident.impact)
    readonly property var updates: {
        var all = card.incident.incident_updates || [];
        return card.expandable ? (card.expanded ? all : []) : all.slice(0, 2);
    }

    // See RowActions.qml — same reasoning: stay opaque on "solid", let the
    // frosted/tinted popup show through on "translucent"/"glass".
    readonly property real cardAlpha: {
        switch (Plasmoid.configuration.surfaceMode) {
        case "glass":
            return Plasmoid.configuration.popupOpacity;
        case "translucent":
            return 0.3;
        default:
            return 1;
        }
    }

    implicitHeight: body.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(Kirigami.Theme.alternateBackgroundColor.r, Kirigami.Theme.alternateBackgroundColor.g, Kirigami.Theme.alternateBackgroundColor.b, card.cardAlpha)

    TapHandler {
        enabled: card.expandable
        onTapped: card.expanded = !card.expanded
    }

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

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: card.incident.name || ""
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: card.expanded ? 4 : 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Kirigami.Icon {
                visible: card.expandable
                source: card.expanded ? "arrow-up" : "arrow-down"
                isMask: true
                color: Kirigami.Theme.disabledTextColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
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

        PlasmaComponents.Label {
            visible: card.expanded && text !== ""
            text: (card.incident.components || []).map(function (component) {
                return component.name;
            }).join(", ")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
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
