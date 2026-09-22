import QtQuick
import QtQuick.Layouts

Rectangle {
    id: bar

    required property var theme
    property var accent: theme.accent
    property string currentId: ""
    property var tabs: []

    signal selected(string id)

    Layout.fillWidth: true
    Layout.preferredHeight: 28
    radius: bar.theme.radiusSmall
    color: bar.theme.surfaceAlt
    border.width: 1
    border.color: bar.theme.line

    RowLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2

        Repeater {
            model: bar.tabs

            Rectangle {
                id: tabItem
                required property var modelData
                readonly property bool active: bar.currentId === modelData.id

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: bar.theme.radiusSmall - 2
                color: active ? Qt.rgba(bar.accent.r, bar.accent.g, bar.accent.b, 0.20) : "transparent"
                border.width: active ? 1 : 0
                border.color: Qt.rgba(bar.accent.r, bar.accent.g, bar.accent.b, 0.35)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 4
                    horizontalAlignment: Text.AlignHCenter
                    text: tabItem.modelData.label
                    font.pixelSize: 11
                    font.bold: tabItem.active
                    color: tabItem.active ? bar.accent : bar.theme.text
                    opacity: tabItem.active ? 1.0 : 0.6
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.selected(tabItem.modelData.id)
                }
            }
        }
    }
}
