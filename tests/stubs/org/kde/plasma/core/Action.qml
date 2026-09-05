import QtQuick

QtObject {
    id: action

    component IconGroup: QtObject {
        property string name: ""
    }

    property string text: ""
    property IconGroup icon: IconGroup {}
    property bool enabled: true
    property bool isSeparator: false

    signal triggered
}
