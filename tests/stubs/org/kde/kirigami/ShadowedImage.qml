import QtQuick

Image {
    property real radius: 0
    property color color: "transparent"
    property var shadow: QtObject {}
    property var border: QtObject {}
    fillMode: Image.PreserveAspectCrop
}
