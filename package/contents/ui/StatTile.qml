// One number with a label and a glyph. Fixed width so a grid of them lines up.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/Format.js" as Fmt

RowLayout {
    id: tile

    property string iconName: ""
    property string label: ""
    property int value: 0
    property string tone: "muted"

    readonly property Tones tones: Tones {}

    spacing: Math.round(Kirigami.Units.smallSpacing * 1.25)

    Kirigami.Icon {
        source: tile.iconName
        color: tile.tones.of(tile.tone)
        isMask: true
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        Layout.alignment: Qt.AlignVCenter
    }

    PlasmaComponents.Label {
        text: Fmt.compact(tile.value)
        font.weight: Font.DemiBold
        Layout.alignment: Qt.AlignVCenter
    }

    PlasmaComponents.Label {
        text: tile.label
        color: Kirigami.Theme.disabledTextColor
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
    }
}
