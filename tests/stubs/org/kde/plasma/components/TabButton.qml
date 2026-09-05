import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.TabButton {
    id: button

    /** The stub TabBar wraps its children in a RowLayout, so it is one up. */
    readonly property var bar: button.parent ? button.parent.parent : null

    padding: Kirigami.Units.smallSpacing

    // The default a bar driven by `currentIndex` needs. A caller that binds
    // `checked` itself (TabStrip does) replaces this binding entirely.
    checked: button.bar && button.bar.indexOfBarItem !== undefined ? button.bar.indexOfBarItem(button) === button.bar.currentIndex : false

    background: Rectangle {
        color: button.checked ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15) : hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06) : "transparent"

        // Plasma marks the current tab with a line along the header edge.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            visible: button.checked
            color: Kirigami.Theme.highlightColor
        }
    }
}
