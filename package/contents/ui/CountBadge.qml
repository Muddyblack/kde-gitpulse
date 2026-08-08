// The tray count badge.
//
// Only ever shows "needs you" — a badge that also counted watched threads is a
// badge people stop reading.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: badge

    readonly property Tones tones: Tones {}

    property int count: 0
    /** Red rather than accent when the count is dominated by failures. */
    property bool urgent: false

    readonly property string label: badge.count > 99 ? "99+" : String(badge.count)

    visible: badge.count > 0
    implicitWidth: Math.max(height, text.implicitWidth + Kirigami.Units.smallSpacing * 1.5)
    implicitHeight: Math.round(Kirigami.Units.iconSizes.small * 0.72)
    radius: height / 2
    color: badge.urgent ? Kirigami.Theme.negativeTextColor : badge.tones.accent

    // A ring in the panel's own colour keeps the badge legible where it
    // overlaps the avatar.
    border.width: Math.max(1, Math.round(height / 10))
    border.color: Kirigami.Theme.backgroundColor

    PlasmaComponents.Label {
        id: text

        anchors.centerIn: parent
        text: badge.label
        color: badge.urgent ? Kirigami.Theme.backgroundColor : badge.tones.accentText
        font.pixelSize: Math.round(badge.height * 0.68)
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    // A brief swell when the number changes, so a new arrival registers
    // peripherally without an animation that loops forever.
    SequentialAnimation {
        id: bump

        NumberAnimation {
            target: badge
            property: "scale"
            to: 1.35
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: badge
            property: "scale"
            to: 1
            duration: Kirigami.Units.shortDuration
        }
    }

    onCountChanged: {
        if (badge.count > 0)
            bump.restart();
    }
}
