// Status pill: tinted background, optional glyph, lowercase label.
//
// Platform-neutral — plain QtQuick only, no Kirigami/PlasmaComponents or
// Quickshell import, so the Plasma widget and the Quickshell frontend use
// this exact file instead of maintaining two copies that quietly drift (see
// issue #5). `theme` just needs `of(tone)` and `wash(tone, alpha)`; both
// Tones.qml and hyprland/Theme.qml already have that shape.
//
// Icon rendering is the one thing that cannot be shared: KDE resolves named
// icons through the system icon theme (Kirigami.Icon), Hyprland draws its own
// glyph set (no icon theme available outside Plasma). So the icon is injected
// as `iconDelegate` — a Component whose root item exposes `iconName`,
// `color` and `spinning`, wired reactively below.
import QtQuick

Rectangle {
    id: pill

    required property var theme
    property string text: ""
    property string tone: "muted"
    property string iconName: ""
    property bool spinning: false
    property Component iconDelegate: null

    implicitWidth: row.implicitWidth + 14
    implicitHeight: 18
    radius: height / 2
    color: pill.theme.wash(pill.tone, 0.16)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Loader {
            id: iconLoader

            anchors.verticalCenter: parent.verticalCenter
            active: pill.iconName !== "" && pill.iconDelegate !== null
            visible: active
            sourceComponent: pill.iconDelegate
        }

        Binding {
            target: iconLoader.item
            property: "iconName"
            value: pill.iconName
            when: iconLoader.item !== null
        }
        Binding {
            target: iconLoader.item
            property: "color"
            value: pill.theme.of(pill.tone)
            when: iconLoader.item !== null
        }
        Binding {
            target: iconLoader.item
            property: "spinning"
            value: pill.spinning
            when: iconLoader.item !== null
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            color: pill.theme.of(pill.tone)
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
}
