pragma Singleton
import QtQuick

// Breeze Dark's palette, so a screenshot from the stub run looks like the
// desktop it is standing in for.
QtObject {
    readonly property color textColor: "#fcfcfc"
    readonly property color disabledTextColor: "#7f8c8d"
    readonly property color backgroundColor: "#1b1e20"
    readonly property color alternateBackgroundColor: "#232629"
    readonly property color highlightColor: "#3daee9"
    readonly property color highlightedTextColor: "#fcfcfc"
    readonly property color positiveTextColor: "#27ae60"
    readonly property color negativeTextColor: "#da4453"
    readonly property color neutralTextColor: "#f67400"
    readonly property color linkColor: "#2980b9"

    readonly property font defaultFont: Qt.font({
        family: "sans-serif",
        pixelSize: 13
    })
    readonly property font smallFont: Qt.font({
        family: "sans-serif",
        pixelSize: 11
    })

    property int colorSet: 0
    property bool inherit: true
}
