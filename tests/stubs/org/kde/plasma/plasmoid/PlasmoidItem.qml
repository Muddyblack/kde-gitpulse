import QtQuick

Item {
    property Component compactRepresentation: null
    property Component fullRepresentation: null
    property Component toolTipItem: null
    property Component preferredRepresentation: null
    property string toolTipMainText: ""
    property string toolTipSubText: ""
    property int switchWidth: -1
    property int switchHeight: -1
    property bool expanded: false
}
