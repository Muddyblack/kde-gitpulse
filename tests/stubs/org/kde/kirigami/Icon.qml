// Kirigami.Icon, without an icon theme.
//
// The Plasma build resolves names like "vcs-merge-request" through the user's
// icon theme, which does not exist in a bare container. Drawing an empty
// placeholder box instead made every screenshot from this harness a grid of
// little squares — structurally correct and completely unreadable.
//
// So this maps the Breeze names the widget actually uses onto the vector
// glyphs the Quickshell frontend already carries, and draws those. Nothing is
// duplicated: hyprland/Icon.qml and hyprland/Icons.js are the same files that
// ship. The shapes are Gitpulse's own glyph set rather than Breeze's, so a
// screenshot from here shows *an* icon of the right meaning at the right size,
// not the exact art a Plasma user sees.
import QtQuick

import "../../../../../hyprland" as Glyph
import "BreezeNames.js" as Breeze

Item {
    id: icon

    property var source: ""
    property color color: "transparent"
    property bool isMask: false
    property bool selected: false
    property bool active: false

    implicitWidth: 16
    implicitHeight: 16

    readonly property string glyphName: Breeze.glyphFor(String(icon.source))

    Glyph.Icon {
        anchors.fill: parent
        name: icon.glyphName
        // `color` is only honoured for a masked icon in real Kirigami; an
        // unmasked one keeps the theme's own colours, which here means the
        // text colour rather than transparent.
        color: icon.isMask && icon.color.a > 0 ? icon.color : "#fcfcfc"
    }

    // A name with no mapping is worth seeing rather than silently missing:
    // an unmapped icon in a screenshot is a hint that the table needs a row.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: icon.glyphName === "" && String(icon.source) !== ""
        radius: 2
        color: "transparent"
        border.width: 1
        border.color: "#f67400"
        opacity: 0.6
    }
}
