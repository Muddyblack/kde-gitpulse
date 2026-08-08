// A verb in the row drawer. Filled when it is the primary action.
import QtQuick

Rectangle {
    id: button

    required property var theme
    property string text: ""
    property string iconName: ""
    property bool primary: false
    property bool danger: false

    signal clicked

    readonly property color ink: button.primary ? button.theme.accentText : button.danger && hover.hovered ? button.theme.negative : hover.hovered ? button.theme.accent : button.theme.text

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 26
    radius: button.theme.radiusSmall
    color: button.primary ? button.theme.accent : hover.hovered ? button.theme.surfaceAlt : "transparent"
    border.width: button.primary ? 0 : 1
    border.color: hover.hovered ? (button.danger ? button.theme.negative : button.theme.accent) : button.theme.line

    Behavior on color {
        ColorAnimation {
            duration: button.theme.shortDuration
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()

        readonly property bool hovered: containsMouse
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 13
            height: 13
            name: button.iconName
            color: button.ink
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            color: button.ink
            font.pixelSize: 12
        }
    }
}
