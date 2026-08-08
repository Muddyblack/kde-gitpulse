// Circular avatar with an initials fallback.
//
// MultiEffect ships with qtdeclarative, so this needs no module the Quickshell
// frontend does not already have.
import QtQuick
import QtQuick.Effects

Item {
    id: avatar

    required property var theme
    property string source: ""
    property string login: ""

    readonly property bool ready: picture.status === Image.Ready && avatar.source !== ""

    implicitWidth: 40
    implicitHeight: 40

    Image {
        id: picture

        anchors.fill: parent
        source: avatar.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
        // A single decode size keeps the shared Qt cache reusable between the
        // small header face, profile portrait and activity rows.
        sourceSize.width: 128
        sourceSize.height: 128
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: width / 2
        color: "black"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: picture
        maskEnabled: true
        maskSource: mask
        visible: avatar.ready
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !avatar.ready
        color: Qt.rgba(avatar.theme.accent.r, avatar.theme.accent.g, avatar.theme.accent.b, 0.22)

        Text {
            anchors.centerIn: parent
            text: avatar.login.length ? avatar.login.substring(0, 2).toUpperCase() : "?"
            color: avatar.theme.accent
            font.pixelSize: Math.round(parent.height * 0.4)
            font.bold: true
        }
    }
}
