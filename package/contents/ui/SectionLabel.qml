// A heading inside a scrolling pane: title on the left, quiet aside on the right.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: section

    property string text: ""
    property string hint: ""

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        text: section.text
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    PlasmaComponents.Label {
        text: section.hint
        visible: section.hint !== ""
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
    }
}
