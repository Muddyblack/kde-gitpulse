// Language mix across the user's own repositories.
//
// Colours come from GitHub's own per-language palette via the API, so this
// file carries no hard-coded language colours to go stale — and the one
// exception, the "Other" bucket, uses the theme's disabled colour.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: bar

    /** Output of Contract.languages(): [{ name, share, color }]. */
    required property var languages

    spacing: Kirigami.Units.smallSpacing

    function colorFor(lang) {
        return lang.color && lang.color.length ? lang.color : Kirigami.Theme.disabledTextColor;
    }

    visible: bar.languages.length > 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.round(Kirigami.Units.smallSpacing * 1.75)
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        clip: true

        Row {
            anchors.fill: parent

            Repeater {
                model: bar.languages

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width * modelData.share / 100
                    height: parent.height
                    color: bar.colorFor(modelData)

                    HoverHandler {
                        id: hover
                    }

                    PlasmaComponents.ToolTip.visible: hover.hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.text: i18n("%1 — %2%", modelData.name, Math.round(modelData.share))
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing * 1.5

        Repeater {
            model: bar.languages

            delegate: RowLayout {
                required property var modelData

                spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

                Rectangle {
                    implicitWidth: Math.round(Kirigami.Units.smallSpacing * 1.5)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: bar.colorFor(parent.modelData)
                }

                PlasmaComponents.Label {
                    text: i18nc("language name and its share", "%1 %2%", parent.modelData.name, Math.round(parent.modelData.share))
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }
    }
}
