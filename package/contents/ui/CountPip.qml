// A tab's count. Accent when it needs you, quiet grey when it is only a total.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: pip

    readonly property Tones tones: Tones {}

    property int count: 0
    property bool prominent: false

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + Kirigami.Units.smallSpacing * 1.5)
    implicitHeight: Math.round(Kirigami.Theme.smallFont.pixelSize * 1.35)
    radius: height / 2
    color: pip.prominent ? pip.tones.accent : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)

    PlasmaComponents.Label {
        id: label

        anchors.centerIn: parent
        text: pip.count > 99 ? "99+" : String(pip.count)
        color: pip.prominent ? pip.tones.accentText : Kirigami.Theme.disabledTextColor
        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.9)
        font.weight: Font.Bold
    }
}
