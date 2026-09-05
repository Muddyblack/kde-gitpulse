import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: message

    enum Position {
        Header,
        Inline,
        Footer
    }

    property string text: ""
    property int type: Kirigami.MessageType.Information
    property bool showCloseButton: false
    /** Header / Inline / Footer — placement only, so nothing reads it here. */
    property int position: 0
    property list<QtObject> actions

    readonly property color tint: message.type === Kirigami.MessageType.Positive ? Kirigami.Theme.positiveTextColor : message.type === Kirigami.MessageType.Error ? Kirigami.Theme.negativeTextColor : message.type === Kirigami.MessageType.Warning ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor

    implicitHeight: body.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(message.tint.r, message.tint.g, message.tint.b, 0.15)
    border.width: 1
    border.color: Qt.rgba(message.tint.r, message.tint.g, message.tint.b, 0.4)

    RowLayout {
        id: body

        x: Kirigami.Units.largeSpacing
        y: Kirigami.Units.largeSpacing
        width: message.width - Kirigami.Units.largeSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: message.text
            color: Kirigami.Theme.textColor
            wrapMode: Text.Wrap
        }

        Repeater {
            model: message.actions

            // `visible` is not decoration: Banner.qml uses it to decide that
            // "Configure…" belongs on a token problem and not on a GitHub
            // outage. A stub that ignores it invents buttons the widget does
            // not show.
            delegate: QQC2.Button {
                required property var modelData

                visible: modelData ? modelData.visible : false
                text: modelData ? modelData.text : ""
                onClicked: modelData.trigger()
            }
        }
    }
}
