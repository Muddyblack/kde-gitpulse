import QtQuick

// Runs nothing: the stub environment has no Plasma data engines, and a test
// must not shell out anyway.
QtObject {
    property string engine: ""
    property var connectedSources: []

    signal newData(string sourceName, var data)

    function connectSource(source) {
    }
    function disconnectSource(source) {
    }
}
