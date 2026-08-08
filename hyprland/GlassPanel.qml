// The popup's surface.
//
// "Glass" is a tinted card with a hairline border and a bright inner edge along
// the top — the same recipe as the other widgets in this collection. The actual
// frosting is the compositor's job: on Hyprland add a layer rule, e.g.
//
//     layerrule = blur, quickshell
//     layerrule = ignorealpha 0.3, quickshell
//
// Without that the panel is simply translucent rather than milky, which still
// looks deliberate.
import QtQuick

Rectangle {
    id: panel

    required property var theme
    /** false → a plain opaque card, no border sheen. */
    property bool glass: true

    radius: panel.theme.radius
    color: panel.glass ? panel.theme.background : Qt.rgba(panel.theme.ink.r, panel.theme.ink.g, panel.theme.ink.b, 1)
    border.width: 1
    border.color: panel.glass ? Qt.rgba(1, 1, 1, 0.13) : panel.theme.line

    // The lit top edge is what sells glass: real frosted surfaces catch light
    // where they meet the bezel.
    Rectangle {
        visible: panel.glass
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: panel.radius
        anchors.rightMargin: panel.radius
        anchors.topMargin: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.22)
    }
}
