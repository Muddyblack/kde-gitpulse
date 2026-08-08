// Copilot pane for the Quickshell frontend.
//
// Same honesty as the Plasma side: GitHub publishes no per-user completion or
// acceptance figures, so this shows service health, billed usage when the
// token can read it, and says why when it cannot.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Layouts

import "../package/contents/code/Format.js" as Format
import "../package/contents/code/GitHub.js" as GH

QC.ScrollView {
    id: pane

    required property var theme
    required property var engine

    readonly property var usage: pane.engine.copilot

    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: pane.availableWidth
        spacing: pane.theme.spacing

        Text {
            Layout.fillWidth: true
            text: qsTr("Service health")
            color: pane.theme.textDim
            font.pixelSize: 11
        }

        Repeater {
            model: pane.engine.copilotComponents

            delegate: RowLayout {
                id: comp

                required property var modelData

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
        }

        Text {
            visible: pane.engine.copilotComponents.length === 0
            Layout.fillWidth: true
            text: qsTr("GitHub is not reporting any Copilot components right now.")
            color: pane.theme.textDim
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall
            implicitHeight: 1
            color: pane.theme.line
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Billed usage this month")
            color: pane.theme.textDim
            font.pixelSize: 11
        }

        RowLayout {
            visible: pane.usage !== null
            Layout.fillWidth: true
            spacing: pane.theme.spacing * 2

            ColumnLayout {
                spacing: 0

                Text {
                    text: pane.usage ? Format.compact(Math.round(pane.usage.quantity)) : "0"
                    color: pane.theme.text
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Text {
                    text: qsTr("premium requests")
                    color: pane.theme.textDim
                    font.pixelSize: 10
                }
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: pane.usage ? pane.usage.netAmount.toFixed(2) : "0.00"
                    color: pane.usage && pane.usage.netAmount > 0 ? pane.theme.neutral : pane.theme.positive
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                }

                Text {
                    text: qsTr("net charge")
                    color: pane.theme.textDim
                    font.pixelSize: 10
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: pane.usage ? pane.usage.skus : []

            delegate: RowLayout {
                id: sku

                required property var modelData

                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: sku.modelData.name
                    color: pane.theme.textDim
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    text: Format.compact(sku.modelData.quantity)
                    color: pane.theme.textDim
                    font.pixelSize: 10
                    font.family: "monospace"
                }
            }
        }

        Text {
            visible: pane.usage === null
            Layout.fillWidth: true
            text: pane.engine.primaryError === GH.ERR.NO_TOKEN ? qsTr("Add a GitHub token to see billed Copilot usage.") : (pane.engine.errorFor("copilot") === GH.ERR.FORBIDDEN || pane.engine.errorFor("copilot") === GH.ERR.NOT_FOUND) ? qsTr("GitHub does not expose per-user Copilot statistics. Billed usage needs a fine-grained token with the “Plan” read permission; completion and acceptance figures exist only for organisation admins.") : qsTr("No Copilot charges recorded this month.")
            color: pane.theme.textDim
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
