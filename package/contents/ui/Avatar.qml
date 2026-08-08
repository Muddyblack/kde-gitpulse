// The signed-in user's avatar, with one fallback chain in one place:
// picture → initials → GitHub mark.
//
// Deliberately not Kirigami Addons' Avatar: that would add a runtime module
// the widget otherwise does not need, and "installs and works" is the point.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: avatar

    readonly property Tones tones: Tones {}

    property string source: ""
    property string login: ""

    readonly property bool ready: probe.status === Image.Ready && avatar.source !== ""
    readonly property string initials: avatar.login.length ? avatar.login.substring(0, 2).toUpperCase() : ""

    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: Kirigami.Units.iconSizes.smallMedium

    // Loaded only to learn whether the picture arrived; Qt serves the visible
    // copy below from the same cache entry, so this costs one request, not two.
    Image {
        id: probe

        source: avatar.source
        visible: false
        asynchronous: true
        cache: true
        // Every surface asks for the same decode size, allowing Qt to reuse
        // one cached image instead of creating a size-specific copy per tab.
        sourceSize.width: 128
        sourceSize.height: 128
    }

    Kirigami.ShadowedImage {
        anchors.fill: parent
        source: avatar.ready ? avatar.source : ""
        radius: width / 2
        visible: avatar.ready
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !avatar.ready
        color: avatar.initials.length ? Qt.rgba(avatar.tones.accent.r, avatar.tones.accent.g, avatar.tones.accent.b, 0.25) : "transparent"

        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: avatar.initials.length > 0
            text: avatar.initials
            color: avatar.tones.accent
            font.pixelSize: Math.round(parent.height * 0.42)
            font.weight: Font.Bold
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.86)
            height: width
            visible: avatar.initials.length === 0
            source: Qt.resolvedUrl("../icons/github-mark.svg")
            color: Kirigami.Theme.textColor
            isMask: true
        }
    }
}
