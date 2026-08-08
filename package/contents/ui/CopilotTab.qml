// Copilot: is it up, and what has it cost.
//
// An honest tab. GitHub publishes no per-user completion or acceptance-rate
// endpoint — those exist only for organisation and enterprise admins — so this
// shows service health (which needs no token at all), billed usage when the
// token can read it, and organisation metrics when one is configured. It does
// not invent an "acceptance rate" to fill the space.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

PlasmaComponents.ScrollView {
    id: tab

    required property var engine
    required property var host

    readonly property var usage: tab.engine.copilot
    readonly property string err: tab.engine.errorFor("copilot")
    readonly property Tones tones: Tones {}

    contentWidth: availableWidth

    ColumnLayout {
        width: tab.availableWidth
        spacing: Kirigami.Units.smallSpacing * 2

        // ── service health ──────────────────────────────────────────────────
        SectionLabel {
            text: i18n("Service health")
            hint: i18n("live, no token needed")
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: 0
        }

        Repeater {
            model: tab.engine.copilotComponents

            delegate: ServiceRow {
                required property var modelData

                name: modelData.name
                status: modelData.status
                tone: modelData.tone
                Layout.fillWidth: true
            }
        }

        PlasmaComponents.Label {
            visible: tab.engine.copilotComponents.length === 0
            text: i18n("GitHub is not reporting any Copilot components right now.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        // ── billed usage ────────────────────────────────────────────────────
        SectionLabel {
            text: i18n("Billed usage this month")
            hint: tab.usage ? i18n("premium requests") : ""
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        GridLayout {
            visible: tab.usage !== null
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Math.round(Kirigami.Units.smallSpacing * 1.25)
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2

            StatTile {
                iconName: "computer"
                label: i18n("requests")
                value: tab.usage ? Math.round(tab.usage.quantity) : 0
                tone: "accent"
                Layout.fillWidth: true
            }

            StatTile {
                iconName: "package-installed-updated"
                label: i18n("included")
                value: tab.usage ? Math.round(tab.usage.included) : 0
                tone: "positive"
                Layout.fillWidth: true
            }
        }

        RowLayout {
            visible: tab.usage !== null
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2

            PlasmaComponents.Label {
                text: i18n("Net charge")
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: tab.usage ? tab.usage.netAmount.toFixed(2) : "0.00"
                font.family: "monospace"
                font.weight: Font.DemiBold
                color: tab.usage && tab.usage.netAmount > 0 ? tab.tones.neutral : tab.tones.positive
            }
        }

        Repeater {
            model: tab.usage ? tab.usage.skus : []

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing * 2
                Layout.rightMargin: Kirigami.Units.smallSpacing * 2

                PlasmaComponents.Label {
                    text: parent.modelData.name
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: Fmt.compact(parent.modelData.quantity)
                    font.family: "monospace"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }

        // ── organisation metrics ────────────────────────────────────────────
        SectionLabel {
            visible: tab.usage !== null && tab.usage.org !== undefined
            text: i18n("Organisation")
            hint: tab.usage && tab.usage.org ? tab.usage.org : ""
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        GridLayout {
            visible: tab.usage !== null && tab.usage.org !== undefined
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2

            StatTile {
                iconName: "system-users"
                label: i18n("active users")
                value: tab.usage && tab.usage.orgActive ? tab.usage.orgActive : 0
                tone: "accent"
                Layout.fillWidth: true
            }

            StatTile {
                iconName: "checkmark"
                label: i18n("engaged users")
                value: tab.usage && tab.usage.orgEngaged ? tab.usage.orgEngaged : 0
                tone: "positive"
                Layout.fillWidth: true
            }
        }

        // ── why there is nothing here ───────────────────────────────────────
        Kirigami.InlineMessage {
            visible: tab.usage === null
            type: Kirigami.MessageType.Information
            text: tab.explanation
            position: Kirigami.InlineMessage.Position.Inline
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
        }

        Item {
            Layout.fillHeight: true
        }
    }

    readonly property string explanation: {
        if (tab.engine.primaryError === GH.ERR.NO_TOKEN)
            return i18n("Add a GitHub token to see billed Copilot usage.");
        switch (tab.err) {
        case GH.ERR.FORBIDDEN:
        case GH.ERR.NOT_FOUND:
            return i18n("GitHub does not expose per-user Copilot statistics. Billed usage needs a fine-grained token with the “Plan” read permission on your account; completion and acceptance figures exist only for organisation admins.");
        case GH.ERR.NONE:
        case "":
            return i18n("No Copilot charges recorded this month.");
        default:
            return i18n("Could not read billing usage: %1", tab.engine.messageFor("copilot"));
        }
    }
}
