// Per-tab quick filters, with live counts.
//
// Counts on the chips are the cheapest way to answer "is it worth clicking
// this?" — a filter that turns out to be empty is a wasted interaction.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/Contract.js" as Contract

Flickable {
    id: chips

    required property var items // already normalised, pre-filter
    required property string tab
    required property string current

    signal picked(string id)

    readonly property Tones tones: Tones {}

    readonly property var defs: {
        switch (chips.tab) {
        case "inbox":
            return [
                {
                    id: "all",
                    label: i18n("All")
                },
                {
                    id: "needs",
                    label: i18n("Needs you")
                },
                {
                    id: "mention",
                    label: i18n("Mentions")
                },
                {
                    id: "unread",
                    label: i18n("Unread")
                }
            ];
        case "actions":
            return [
                {
                    id: "all",
                    label: i18n("All")
                },
                {
                    id: "failed",
                    label: i18n("Failed")
                },
                {
                    id: "active",
                    label: i18n("Running")
                }
            ];
        case "pulls":
            return [
                {
                    id: "all",
                    label: i18n("All")
                },
                {
                    id: "review",
                    label: i18n("Review requested")
                },
                {
                    id: "mine",
                    label: i18n("Mine")
                }
            ];
        case "issues":
            return [
                {
                    id: "all",
                    label: i18n("All")
                },
                {
                    id: "assigned",
                    label: i18n("Assigned to me")
                },
                {
                    id: "mine",
                    label: i18n("Opened by me")
                }
            ];
        default:
            return [];
        }
    }

    /** Same call the list makes, so a chip cannot advertise a count it will not yield. */
    function countFor(id) {
        return Contract.applyChip(chips.items, id).length;
    }

    visible: chips.defs.length > 0
    implicitHeight: visible ? row.implicitHeight : 0
    contentWidth: row.implicitWidth
    contentHeight: implicitHeight
    flickableDirection: Flickable.HorizontalFlick
    clip: true

    RowLayout {
        id: row

        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: chips.defs

            delegate: Rectangle {
                id: chip

                required property var modelData

                readonly property int n: chips.countFor(modelData.id)
                readonly property bool checked: chips.current === modelData.id
                readonly property bool chipEnabled: chip.n > 0 || chip.modelData.id === "all" || chip.checked

                implicitWidth: chipRow.implicitWidth + Kirigami.Units.gridUnit
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.35)
                radius: height / 2
                color: chip.checked ? chips.tones.accent : "transparent"
                border.width: chip.checked ? 0 : 1
                border.color: hover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)
                opacity: chip.chipEnabled ? 1 : 0.45

                Accessible.role: Accessible.Button
                Accessible.name: chip.modelData.label

                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }

                HoverHandler {
                    id: hover

                    enabled: chip.chipEnabled
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: chip.chipEnabled
                    onTapped: chips.picked(chip.modelData.id)
                }

                RowLayout {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

                    PlasmaComponents.Label {
                        text: chip.modelData.label
                        color: chip.checked ? chips.tones.accentText : Kirigami.Theme.disabledTextColor
                        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.95)
                    }

                    PlasmaComponents.Label {
                        visible: chip.n > 0
                        text: chip.n
                        color: chip.checked ? chips.tones.accentText : Kirigami.Theme.disabledTextColor
                        font.family: "monospace"
                        font.weight: Font.DemiBold
                        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.85)
                        opacity: chip.checked ? 0.8 : 1
                    }
                }
            }
        }
    }
}
