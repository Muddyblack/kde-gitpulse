// Notifications, the undo window, and which tab opens first.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_notifyEnabled: notifyBox.checked
    property alias cfg_groupByRepo: groupBox.checked
    property alias cfg_undoWindowSec: undoSpin.value
    property string cfg_defaultTab: "inbox"

    readonly property var tabChoices: [
        {
            id: "inbox",
            label: i18n("Inbox")
        },
        {
            id: "actions",
            label: i18n("Actions")
        },
        {
            id: "pulls",
            label: i18n("Pull requests")
        },
        {
            id: "issues",
            label: i18n("Issues")
        },
        {
            id: "profile",
            label: i18n("Profile")
        },
        {
            id: "copilot",
            label: i18n("Copilot")
        },
        {
            id: "status",
            label: i18n("Status")
        }
    ]

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: notifyBox

            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Tell the desktop when something new needs me")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Gitpulse raises a normal desktop notification. Whether that makes a sound, shows a popup or stays silent during Do Not Disturb is decided in System Settings ▸ Notifications, alongside every other application.")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: tabCombo

            Kirigami.FormData.label: i18n("Open on:")
            textRole: "label"
            valueRole: "id"
            model: page.tabChoices
            onActivated: page.cfg_defaultTab = currentValue

            Component.onCompleted: {
                for (var i = 0; i < page.tabChoices.length; i++) {
                    if (page.tabChoices[i].id === page.cfg_defaultTab) {
                        currentIndex = i;
                        return;
                    }
                }
                currentIndex = 0;
            }
        }

        QQC2.CheckBox {
            id: groupBox

            Kirigami.FormData.label: i18n("Lists:")
            text: i18n("Group by repository")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: undoSpin

            Kirigami.FormData.label: i18n("Undo window:")
            from: 0
            to: 30
            textFromValue: (value, locale) => value === 0 ? i18n("no undo") : i18np("%1 second", "%1 seconds", value)
            valueFromText: text => parseInt(text, 10) || 0
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("“Mark all read” waits this long before contacting GitHub, because GitHub cannot mark a thread unread again. Set it to zero to send immediately.")
        }
    }
}
