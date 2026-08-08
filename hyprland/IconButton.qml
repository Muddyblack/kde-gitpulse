// A flat, tintable glyph button.
import QtQuick

Rectangle {
    id: button

    required property var theme
    property string iconName: ""
    property string tip: ""
    property bool active: false
    property int size: 26

    signal clicked

    implicitWidth: button.size
    implicitHeight: button.size
    radius: button.theme.radiusSmall
    color: button.active ? button.theme.wash("accent", 0.22) : hover.hovered ? button.theme.surfaceAlt : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: button.theme.shortDuration
        }
    }

    // A MouseArea, not a TapHandler: handlers on a child do not stop the ones
    // on an ancestor, so a chevron built from TapHandler also fired the row's
    // "open in browser". A MouseArea accepts the press and ends it there.
    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()

        readonly property bool hovered: containsMouse
    }

    Icon {
        anchors.centerIn: parent
        width: Math.round(button.size * 0.6)
        height: Math.round(button.size * 0.6)
        name: button.iconName
        color: button.active ? button.theme.accent : hover.hovered ? button.theme.text : button.theme.textDim
    }
}
