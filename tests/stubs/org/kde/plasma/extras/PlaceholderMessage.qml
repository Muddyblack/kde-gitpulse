import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    property string iconName: ""
    property string text: ""
    property string explanation: ""
    property int type: 0
    /** The one call-to-action button under the message. */
    property var helpfulAction: null

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large
        source: parent.iconName
        color: Kirigami.Theme.disabledTextColor
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: parent.text
        color: Kirigami.Theme.textColor
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: parent.explanation
        visible: text !== ""
        color: Kirigami.Theme.disabledTextColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }

    QQC2.Button {
        Layout.alignment: Qt.AlignHCenter
        visible: parent.helpfulAction !== null
        text: parent.helpfulAction ? parent.helpfulAction.text : ""
        onClicked: parent.helpfulAction.trigger()
    }
}
