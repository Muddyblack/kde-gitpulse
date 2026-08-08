// GitHub service health, with a 90-day strip per component.
//
// Unauthenticated, so this tab works before the widget is configured — which
// is precisely when someone is most likely to be wondering whether the problem
// is their token or GitHub.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/Contract.js" as Contract
import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

PlasmaComponents.ScrollView {
    id: tab

    required property var engine
    required property var host

    readonly property var summary: tab.engine.statusSummary
    readonly property var live: Contract.activeIncidents(tab.engine.incidents)
    readonly property var history: (tab.engine.incidents || []).slice(0, 12)
    readonly property string indicator: tab.summary && tab.summary.status ? tab.summary.status.indicator : ""
    readonly property Tones tones: Tones {}

    /** "components" | "incidents" — match the Quickshell status view. */
    property string view: "components"

    contentWidth: availableWidth

    ColumnLayout {
        width: tab.availableWidth
        spacing: Kirigami.Units.smallSpacing

        // ── headline ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: 0
            visible: tab.summary !== null
            implicitHeight: headline.implicitHeight + Kirigami.Units.gridUnit
            radius: Kirigami.Units.cornerRadius
            color: tab.tones.wash(Fmt.indicatorTone(tab.indicator), 0.12)
            border.width: 1
            border.color: tab.tones.wash(Fmt.indicatorTone(tab.indicator), 0.35)

            RowLayout {
                id: headline

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Kirigami.Units.smallSpacing * 2
                spacing: Kirigami.Units.smallSpacing * 2

                Kirigami.Icon {
                    source: tab.indicator === "none" ? "checkmark" : tab.indicator === "minor" ? "dialog-warning" : "dialog-error"
                    color: tab.tones.of(Fmt.indicatorTone(tab.indicator))
                    isMask: true
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaExtras.Heading {
                        level: 5
                        text: tab.summary && tab.summary.status ? tab.summary.status.description : ""
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: i18np("Monitoring %1 service", "Monitoring %1 services", tab.engine.statusComponents.length)
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ── view switch ─────────────────────────────────────────────────────
        PlasmaComponents.TabBar {
            id: views

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            currentIndex: tab.view === "components" ? 0 : 1

            PlasmaComponents.TabButton {
                text: i18n("Components")
                onClicked: tab.view = "components"
                Accessible.description: i18np("%1 monitored service", "%1 monitored services", tab.engine.statusComponents.length)
            }

            PlasmaComponents.TabButton {
                text: i18n("Incidents")
                onClicked: tab.view = "incidents"
                Accessible.description: i18np("%1 incident on record", "%1 incidents on record", tab.history.length)
            }
        }

        // ── open incidents (always shown, whichever view is selected) ───────
        SectionLabel {
            visible: tab.live.length > 0
            text: i18np("%1 open incident", "%1 open incidents", tab.live.length)
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: 0
        }

        Repeater {
            model: tab.live

            delegate: IncidentCard {
                required property var modelData

                incident: modelData
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            }
        }

        // ── incident history ────────────────────────────────────────────────
        PlasmaExtras.PlaceholderMessage {
            visible: tab.view === "incidents" && tab.history.length === 0
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit * 2
            text: i18n("No incidents on record")
            explanation: i18n("GitHub has not reported any recent service incidents.")
            iconName: "emblem-ok"
        }

        Repeater {
            model: tab.view === "incidents" ? tab.history : []

            delegate: IncidentCard {
                required property var modelData

                incident: modelData
                expandable: true
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            }
        }

        // ── components ──────────────────────────────────────────────────────
        SectionLabel {
            visible: tab.view === "components" && tab.engine.statusComponents.length > 0
            text: i18n("Components")
            hint: i18n("90 days · incident-free")
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: 0
        }

        Repeater {
            model: tab.view === "components" ? tab.engine.statusComponents : []

            delegate: ServiceRow {
                required property var modelData

                name: modelData.name
                status: modelData.status
                tone: modelData.tone
                strip: Contract.incidentStrip(tab.engine.incidents, modelData.id, 90)
                Layout.fillWidth: true
            }
        }

        PlasmaComponents.Label {
            visible: tab.view === "components" && tab.engine.statusComponents.length > 0
            text: i18n("Strips are built from GitHub's public incident feed, not from published uptime figures.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
        }

        Item {
            Layout.fillHeight: true
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 3
        visible: tab.summary === null

        iconName: tab.engine.errorFor("status") === "" ? "state-sync" : "network-disconnect"
        text: tab.engine.errorFor("status") === "" ? i18n("Checking GitHub…") : i18n("Cannot reach githubstatus.com")
        explanation: tab.engine.errorFor("status") === GH.ERR.OFFLINE ? i18n("No network connection.") : tab.engine.messageFor("status")
    }
}
