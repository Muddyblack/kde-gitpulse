// A quick-filter chip with its live count.
//
// The count is the cheapest way to answer "is it worth clicking this?" — a
// filter that turns out to be empty is a wasted interaction.
import QtQuick

Rectangle {
    id: chip

    required property var theme
    property string text: ""
    property int count: 0
    property bool active: false

    signal clicked

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 22
    radius: height / 2
    color: chip.active ? chip.theme.accent : "transparent"
    border.width: chip.active ? 0 : 1
    border.color: hover.hovered ? chip.theme.lineStrong : chip.theme.line
    opacity: chip.enabled ? 1 : 0.45

    Behavior on color {
        ColorAnimation {
            duration: chip.theme.shortDuration
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        enabled: chip.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()

        readonly property bool hovered: containsMouse
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            color: chip.active ? chip.theme.accentText : chip.theme.textDim
            font.pixelSize: 11
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.count > 0
            text: chip.count
            color: chip.active ? chip.theme.accentText : chip.theme.textFaint
            font.pixelSize: 10
            font.family: "monospace"
            font.weight: Font.Bold
            opacity: chip.active ? 0.8 : 1
        }
    }
}
