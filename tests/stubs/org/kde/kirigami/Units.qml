pragma Singleton
import QtQuick

QtObject {
    readonly property int gridUnit: 18
    readonly property int smallSpacing: 4
    readonly property int largeSpacing: 8
    readonly property int cornerRadius: 5
    readonly property int shortDuration: 150
    readonly property int longDuration: 250
    readonly property int veryLongDuration: 400
    readonly property int toolTipDelay: 700

    readonly property QtObject iconSizes: QtObject {
        readonly property int small: 16
        readonly property int smallMedium: 22
        readonly property int medium: 32
        readonly property int large: 48
        readonly property int huge: 64
    }
}
