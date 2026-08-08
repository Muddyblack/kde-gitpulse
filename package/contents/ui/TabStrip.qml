// Tab bar for a popup barely 22 grid units wide.
//
// Seven labelled tabs will not fit, so only the selected one is named and the
// rest are icon plus count. Every tab still carries a tooltip and an Alt+N
// accelerator, so nothing is discoverable by hovering alone.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.TabBar {
    id: strip

    required property var tabs
    required property var engine
    required property string current

    signal selected(string id)

    position: PlasmaComponents.TabBar.Header

    Repeater {
        model: strip.tabs

        delegate: PlasmaComponents.TabButton {
            id: button

            required property var modelData
            required property int index

            readonly property int count: strip.engine.badge.perTab[modelData.id] || 0
            readonly property int tracked: (strip.engine.sections[modelData.id] || []).length
            readonly property bool active: strip.current === modelData.id

            checked: button.active
            onClicked: strip.selected(button.modelData.id)

            PlasmaComponents.ToolTip.text: i18n("%1  ( Alt+%2 )", button.modelData.label, button.index + 1)
            PlasmaComponents.ToolTip.visible: button.hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

            Accessible.name: button.modelData.label
            Accessible.description: button.count > 0 ? i18np("%1 item needs you", "%1 items need you", button.count) : ""

            // The selected tab earns the extra width its label needs.
            Layout.fillWidth: true
            Layout.preferredWidth: button.active ? 2.2 : 1

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            contentItem: RowLayout {
                spacing: Math.round(Kirigami.Units.smallSpacing * 1.2)

                Kirigami.Icon {
                    source: button.modelData.icon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    color: Kirigami.Theme.textColor
                    isMask: true
                    opacity: button.active ? 1 : 0.8
                }

                PlasmaComponents.Label {
                    text: button.modelData.label
                    visible: button.active
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                CountPip {
                    visible: button.count > 0 || button.tracked > 0
                    count: button.count > 0 ? button.count : button.tracked
                    prominent: button.count > 0
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
