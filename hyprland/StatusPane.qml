// GitHub service health for the Quickshell frontend.
//
// The one pane that needs no token, which is exactly when it is most useful:
// before the widget is configured, and when you are trying to work out whether
// the problem is you or GitHub.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Layouts

import "../package/contents/code/Contract.js" as Contract
import "../package/contents/code/Format.js" as Format

QC.ScrollView {
    id: pane

    required property var theme
    required property var engine

    readonly property var summary: pane.engine.statusSummary
    readonly property var open: Contract.activeIncidents(pane.engine.incidents)
    readonly property string indicator: pane.summary && pane.summary.status ? pane.summary.status.indicator : ""

    /** "components" | "incidents" — the strips answer "when", this answers "what". */
    property string view: "components"

    readonly property var history: (pane.engine.incidents || []).slice(0, 12)

    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: pane.availableWidth
        spacing: pane.theme.spacing

        // ── headline ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: pane.summary !== null
            implicitHeight: headline.implicitHeight + pane.theme.spacing * 2
            radius: pane.theme.radiusSmall
            color: pane.theme.wash(Format.indicatorTone(pane.indicator), 0.12)
            border.width: 1
            border.color: pane.theme.wash(Format.indicatorTone(pane.indicator), 0.35)

            RowLayout {
                id: headline

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: pane.theme.spacing
                spacing: pane.theme.spacing

                Rectangle {
                    implicitWidth: 10
                    implicitHeight: 10
                    radius: 5
                    color: pane.theme.of(Format.indicatorTone(pane.indicator))
                }

                Text {
                    Layout.fillWidth: true
                    text: pane.summary && pane.summary.status ? pane.summary.status.description : ""
                    color: pane.theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
            }
        }

        // ── view switch ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall
            spacing: pane.theme.spacingSmall

            Chip {
                theme: pane.theme
                text: qsTr("Components")
                count: pane.engine.statusComponents.length
                active: pane.view === "components"
                onClicked: pane.view = "components"
            }

            Chip {
                theme: pane.theme
                text: qsTr("Incidents")
                count: pane.history.length
                active: pane.view === "incidents"
                onClicked: pane.view = "incidents"
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // ── open incidents (always up top, whichever view) ──────────────────
        Text {
            visible: pane.open.length > 0
            text: pane.open.length === 1 ? qsTr("1 open incident") : qsTr("%1 open incidents").arg(pane.open.length)
            color: pane.theme.negative
            font.pixelSize: 11
            Layout.topMargin: pane.theme.spacingSmall
        }

        Repeater {
            model: pane.open

            delegate: Rectangle {
                id: card

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: incident.implicitHeight + pane.theme.spacing
                radius: pane.theme.radiusSmall
                color: pane.theme.surface

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    radius: 1
                    color: pane.theme.of(Format.impactTone(card.modelData.impact))
                }

                ColumnLayout {
                    id: incident

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: pane.theme.spacingSmall * 1.5
                    anchors.leftMargin: pane.theme.spacing
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.name || ""
                        color: pane.theme.text
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("%1 · %2 ago").arg(Format.humanise(card.modelData.status || "")).arg(Format.relative(card.modelData.updated_at))
                        color: pane.theme.textDim
                        font.pixelSize: 10
                        font.family: "monospace"
                    }
                }
            }
        }

        // ── incident history ────────────────────────────────────────────────
        Text {
            visible: pane.view === "incidents" && pane.history.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 30
            text: qsTr("No incidents on record.")
            color: pane.theme.textDim
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: pane.view === "incidents" ? pane.history : []

            delegate: IncidentEntry {
                required property var modelData

                theme: pane.theme
                incident: modelData
                Layout.fillWidth: true
            }
        }

        // ── components ──────────────────────────────────────────────────────
        RowLayout {
            visible: pane.view === "components" && pane.engine.statusComponents.length > 0
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall

            Text {
                Layout.fillWidth: true
                text: qsTr("Components")
                color: pane.theme.textDim
                font.pixelSize: 11
            }

            Text {
                text: qsTr("90 days · incident-free")
                color: pane.theme.textDim
                font.pixelSize: 10
                opacity: 0.75
            }
        }

        Repeater {
            model: pane.view === "components" ? pane.engine.statusComponents : []

            delegate: ColumnLayout {
                id: comp

                required property var modelData

                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: pane.theme.spacingSmall * 1.5

                    Rectangle {
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 3.5
                        color: pane.theme.of(comp.modelData.tone)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: comp.modelData.name
                        color: pane.theme.text
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Format.humanise(comp.modelData.status)
                        color: pane.theme.of(comp.modelData.tone)
                        font.pixelSize: 10
                    }
                }

                Strip {
                    theme: pane.theme
                    days: Contract.incidentStrip(pane.engine.incidents, comp.modelData.id, 90)
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.bottomMargin: pane.theme.spacingSmall
                }
            }
        }

        Text {
            visible: pane.view === "components" && pane.engine.statusComponents.length > 0
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall
            text: qsTr("Strips come from GitHub's public incident feed, not from published uptime figures.")
            color: pane.theme.textFaint
            font.pixelSize: 10
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            visible: pane.summary === null
            text: qsTr("Checking githubstatus.com…")
            color: pane.theme.textDim
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: 40
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
