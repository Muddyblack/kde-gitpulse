// Which tabs exist, and how often each source is polled.
//
// The intervals are separate on purpose: the notifications endpoint is cheap
// and wants to be current, the search API is expensive, and a profile changes
// about once a day.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_actionsEnabled: actionsBox.checked
    property alias cfg_pullsEnabled: pullsBox.checked
    property alias cfg_issuesEnabled: issuesBox.checked
    property alias cfg_profileEnabled: profileBox.checked
    property alias cfg_copilotEnabled: copilotBox.checked
    property alias cfg_statusEnabled: statusBox.checked

    property alias cfg_inboxIntervalSec: inboxSpin.value
    property alias cfg_searchIntervalSec: searchSpin.value
    property alias cfg_actionsIntervalSec: actionsSpin.value
    property alias cfg_profileIntervalSec: profileSpin.value
    property alias cfg_statusIntervalSec: statusSpin.value

    property alias cfg_participatingOnly: participatingBox.checked
    property alias cfg_includeRead: includeReadBox.checked

    /** Rough worst case, so the cost of a setting is visible while changing it. */
    readonly property int requestsPerHour: {
        var n = 3600 / Math.max(30, inboxSpin.value);
        if (pullsBox.checked)
            n += 2 * 3600 / Math.max(60, searchSpin.value);
        if (issuesBox.checked)
            n += 3600 / Math.max(60, searchSpin.value);
        if (actionsBox.checked)
            n += (1 + cfgWatchCount) * 3600 / Math.max(60, actionsSpin.value);
        if (profileBox.checked)
            n += 3600 / Math.max(300, profileSpin.value);
        return Math.round(n);
    }
    // The Account page owns this value; 6 is its default and a fair estimate.
    readonly property int cfgWatchCount: 6

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: actionsBox

            Kirigami.FormData.label: i18n("Tabs:")
            text: i18n("Actions — workflow runs")
        }

        QQC2.CheckBox {
            id: pullsBox

            text: i18n("Pull requests")
        }

        QQC2.CheckBox {
            id: issuesBox

            text: i18n("Issues")
        }

        QQC2.CheckBox {
            id: profileBox

            text: i18n("Profile — stats and contribution graph")
        }

        QQC2.CheckBox {
            id: copilotBox

            text: i18n("Copilot")
        }

        QQC2.CheckBox {
            id: statusBox

            text: i18n("GitHub service status")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: participatingBox

            Kirigami.FormData.label: i18n("Inbox:")
            text: i18n("Only threads I participate in")
        }

        QQC2.CheckBox {
            id: includeReadBox

            text: i18n("Also show already-read notifications")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: inboxSpin

            Kirigami.FormData.label: i18n("Inbox every:")
            from: 30
            to: 3600
            stepSize: 30
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: text => parseInt(text, 10)
        }

        QQC2.SpinBox {
            id: searchSpin

            Kirigami.FormData.label: i18n("Pulls and issues every:")
            from: 60
            to: 3600
            stepSize: 30
            enabled: pullsBox.checked || issuesBox.checked
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: text => parseInt(text, 10)
        }

        QQC2.SpinBox {
            id: actionsSpin

            Kirigami.FormData.label: i18n("Actions every:")
            from: 60
            to: 3600
            stepSize: 60
            enabled: actionsBox.checked
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: text => parseInt(text, 10)
        }

        QQC2.SpinBox {
            id: profileSpin

            Kirigami.FormData.label: i18n("Profile every:")
            from: 300
            to: 86400
            stepSize: 300
            enabled: profileBox.checked || copilotBox.checked
            textFromValue: (value, locale) => i18np("%1 minute", "%1 minutes", Math.round(value / 60))
            valueFromText: text => parseInt(text, 10) * 60
        }

        QQC2.SpinBox {
            id: statusSpin

            Kirigami.FormData.label: i18n("Service status every:")
            from: 60
            to: 3600
            stepSize: 60
            enabled: statusBox.checked
            textFromValue: (value, locale) => i18np("%1 second", "%1 seconds", value)
            valueFromText: text => parseInt(text, 10)
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: page.requestsPerHour > 4000 ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
            text: i18n("About %1 requests an hour, of GitHub's 5000. Unchanged data answers 304 and costs nothing, so the real figure is usually far lower.", page.requestsPerHour)
        }
    }
}
