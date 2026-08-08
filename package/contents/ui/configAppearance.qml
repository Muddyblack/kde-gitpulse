// Accent and transparency.
//
// The system accent is the default and the recommended setting — it is what
// makes the widget look like it belongs. The override exists because some
// people want one panel item to stand out, and refusing that is just being
// precious about it.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: page

    property string cfg_accentMode: "system"
    property alias cfg_customAccent: accentButton.color
    property string cfg_surfaceMode: "solid"
    property alias cfg_popupOpacity: opacity.value

    readonly property var swatches: ["#3daee9", "#9b59b6", "#27ae60", "#f67400", "#da4453", "#e93a9a", "#16a085", "#7aa2f7"]

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("Accent:")
            text: i18n("Follow the system colour scheme")
            checked: page.cfg_accentMode !== "custom"
            onToggled: {
                if (checked)
                    page.cfg_accentMode = "system";
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Uses whatever accent you picked in System Settings ▸ Colours, including one derived from your wallpaper.")
        }

        QQC2.RadioButton {
            id: customRadio

            text: i18n("Use a specific colour")
            checked: page.cfg_accentMode === "custom"
            onToggled: {
                if (checked) {
                    page.cfg_accentMode = "custom";
                    if (page.cfg_customAccent === "")
                        page.cfg_customAccent = page.swatches[0];
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Colour:")
            enabled: customRadio.checked
            spacing: Kirigami.Units.smallSpacing

            // The full picker, same control the other widgets in this
            // collection use — presets are a shortcut, not the only option.
            KQuickControls.ColorButton {
                id: accentButton

                showAlphaChannel: false
                dialogTitle: i18n("Gitpulse accent colour")
            }

            Repeater {
                model: page.swatches

                delegate: Rectangle {
                    id: swatch

                    required property string modelData

                    implicitWidth: Kirigami.Units.gridUnit * 1.3
                    implicitHeight: Kirigami.Units.gridUnit * 1.3
                    radius: width / 2
                    color: swatch.modelData
                    border.width: Qt.colorEqual(accentButton.color, swatch.modelData) ? 2 : 0
                    border.color: Kirigami.Theme.textColor

                    TapHandler {
                        onTapped: accentButton.color = swatch.modelData
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: surface

            Kirigami.FormData.label: i18n("Surface:")
            textRole: "label"
            valueRole: "id"
            model: [
                {
                    id: "solid",
                    label: i18n("Solid — the standard Plasma popup")
                },
                {
                    id: "translucent",
                    label: i18n("Translucent — Plasma's frosted background")
                },
                {
                    id: "glass",
                    label: i18n("Glass — tinted card with a lit edge")
                }
            ]
            onActivated: page.cfg_surfaceMode = currentValue

            Component.onCompleted: {
                for (var i = 0; i < model.length; i++) {
                    if (model[i].id === page.cfg_surfaceMode) {
                        currentIndex = i;
                        return;
                    }
                }
                currentIndex = 0;
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Translucent is the most native option: KWin already blurs Plasma's own dialog background, and it follows your Breeze theme. Glass matches the look of the other widgets in this collection.")
        }

        QQC2.Slider {
            id: opacity

            Kirigami.FormData.label: i18n("Glass opacity:")
            enabled: page.cfg_surfaceMode === "glass"
            from: 0.35
            to: 1
            stepSize: 0.05
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        }

        QQC2.Label {
            enabled: page.cfg_surfaceMode === "glass"
            text: i18n("%1%", Math.round(opacity.value * 100))
            font.family: "monospace"
        }
    }
}
