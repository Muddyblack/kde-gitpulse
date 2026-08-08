// A small status pill: tinted background, icon, lowercase label.
//
// The icon is not decoration — it is what makes the state readable without
// relying on colour alone.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: pill

    property string text: ""
    property string tone: "muted"
    property string iconName: ""

    readonly property Tones tones: Tones {}

    implicitWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2.5
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.95)
    radius: height / 2
    color: pill.tones.wash(pill.tone, 0.16)

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

        Kirigami.Icon {
            source: pill.iconName
            visible: pill.iconName !== ""
            color: pill.tones.of(pill.tone)
            isMask: true
            Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.small * 0.62)
            Layout.preferredHeight: Math.round(Kirigami.Units.iconSizes.small * 0.62)
            Layout.alignment: Qt.AlignVCenter
        }

        PlasmaComponents.Label {
            text: pill.text
            color: pill.tones.of(pill.tone)
            font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.88)
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
