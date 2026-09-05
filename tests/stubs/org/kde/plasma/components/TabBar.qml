import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A RowLayout, not QQC2.TabBar.
//
// Plasma's TabBar lays its buttons out with Layout attached properties, and
// TabStrip.qml relies on that: the selected tab claims 2.2× the width so its
// label fits while the others stay icon-plus-count. QQC2.TabBar puts its
// buttons in a ListView, which ignores Layout.* entirely — under that stub
// every tab collapsed to its icon and the strip read as a row of empty boxes.
Item {
    id: bar

    enum Position {
        Header,
        Footer
    }

    property int position: 0
    /**
     * Which tab is current, for the callers that drive the bar by index
     * (StatusTab) rather than by binding `checked` themselves (TabStrip).
     */
    property int currentIndex: 0

    default property alias barItems: row.data

    /** Position of a child in the bar; -1 for anything that is not one. */
    function indexOfBarItem(item) {
        var n = 0;
        for (var i = 0; i < row.children.length; i++) {
            if (row.children[i] === item)
                return n;
            n++;
        }
        return -1;
    }

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
    }

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: 0
    }
}
