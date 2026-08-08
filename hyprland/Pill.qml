// Status pill: tinted background, glyph, lowercase label.
//
// The glyph is not decoration — it is what keeps the state readable without
// relying on colour alone.
import QtQuick

Rectangle {
    id: pill

    required property var theme
    property string text: ""
    property string tone: "muted"
    property string iconName: ""
    property bool spinning: false

    implicitWidth: label.implicitWidth + (glyph.visible ? glyph.width + 4 : 0) + 14
    implicitHeight: 18
    radius: height / 2
    color: pill.theme.wash(pill.tone, 0.16)

    Row {
        anchors.centerIn: parent
        spacing: 4

        Icon {
            id: glyph

            width: 10
            height: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.iconName !== ""
            name: pill.iconName
            color: pill.theme.of(pill.tone)
            spinning: pill.spinning
        }

        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            color: pill.theme.of(pill.tone)
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
}
