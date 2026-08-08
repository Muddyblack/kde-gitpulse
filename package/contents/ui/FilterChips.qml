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

            delegate: PlasmaComponents.Button {
                required property var modelData

                readonly property int n: chips.countFor(modelData.id)

                checkable: true
                checked: chips.current === modelData.id
                flat: !checked
                text: n > 0 ? i18nc("filter name and how many match", "%1 · %2", modelData.label, n) : modelData.label
                enabled: n > 0 || modelData.id === "all" || checked
                onClicked: chips.picked(modelData.id)

                Accessible.name: modelData.label
            }
        }
    }
}
