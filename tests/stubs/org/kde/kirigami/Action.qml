import QtQuick

QtObject {
    id: action

    // A grouped property (`icon.name: "…"`) needs a declared QObject type, not
    // a `var` — hence the inline component.
    component IconGroup: QtObject {
        property string name: ""
        property string source: ""
        property color color: "transparent"
    }

    property string text: ""
    property IconGroup icon: IconGroup {}
    property bool enabled: true
    property bool visible: true
    property bool checkable: false
    property bool checked: false

    signal triggered

    function trigger() {
        action.triggered();
    }
}
