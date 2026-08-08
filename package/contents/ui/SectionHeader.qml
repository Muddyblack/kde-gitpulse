// Sticky divider between list sections.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: header

    readonly property Tones tones: Tones {}

    property string text: ""
    /** The "new since you last looked" divider earns the accent; repos do not. */
    property bool accented: false

    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing * 2

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            id: label

            text: header.text
            elide: Text.ElideRight
            font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.95)
            font.capitalization: header.accented ? Font.AllUppercase : Font.MixedCase
            font.weight: Font.DemiBold
            font.letterSpacing: header.accented ? 0.6 : 0
            color: header.accented ? header.tones.accent : Kirigami.Theme.disabledTextColor
            Layout.maximumWidth: parent.width * 0.75
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
