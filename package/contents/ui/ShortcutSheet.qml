// The "?" overlay.
//
// Every shortcut here also has a visible affordance somewhere; this sheet
// exists so a keyboard user can learn the whole set at once instead of
// discovering it a tooltip at a time.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

Rectangle {
    id: sheet

    signal dismissed

    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.97)

    readonly property var rows: [
        {
            keys: "↑ ↓",
            what: i18n("Move through the list")
        },
        {
            keys: "Enter",
            what: i18n("Open, mark read, close")
        },
        {
            keys: "Ctrl+Enter",
            what: i18n("Open in the background")
        },
        {
            keys: "Space",
            what: i18n("Expand inline actions")
        },
        {
            keys: "M",
            what: i18n("Mark read")
        },
        {
            keys: "Shift+M",
            what: i18n("Mark all read (undoable)")
        },
        {
            keys: "/",
            what: i18n("Filter")
        },
        {
            keys: "Alt+1…9",
            what: i18n("Jump to a tab")
        },
        {
            keys: "G",
            what: i18n("Group by repository")
        },
        {
            keys: "R",
            what: i18n("Refresh now")
        },
        {
            keys: "Esc",
            what: i18n("Clear filter, then close")
        }
    ]

    // Clicking anywhere dismisses; nothing behind the sheet should react.
    TapHandler {
        onTapped: sheet.dismissed()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true

            PlasmaExtras.Heading {
                level: 4
                text: i18n("Keyboard")
                Layout.fillWidth: true
            }

            PlasmaComponents.ToolButton {
                icon.name: "dialog-close"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Close")
                onClicked: sheet.dismissed()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: list.implicitHeight
            clip: true

            ColumnLayout {
                id: list

                width: parent.width
                spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                Repeater {
                    model: sheet.rows

                    delegate: RowLayout {
                        required property var modelData

                        spacing: Kirigami.Units.gridUnit
                        Layout.fillWidth: true

                        PlasmaComponents.Label {
                            text: parent.modelData.keys
                            font.family: "monospace"
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        }

                        PlasmaComponents.Label {
                            text: parent.modelData.what
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
