// Hover breakdown for the tray icon.
//
// Answers "is there anything for me?" without opening anything — which is the
// question the badge raises and cannot itself answer.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

ColumnLayout {
    id: tip

    required property var engine

    readonly property var b: tip.engine.badge

    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2

        Avatar {
            login: tip.engine.viewerLogin
            source: tip.engine.avatarSource || tip.engine.avatarUrl
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        }

        ColumnLayout {
            spacing: 0

            PlasmaExtras.Heading {
                level: 4
                text: i18n("Gitpulse")
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                text: {
                    switch (tip.engine.primaryError) {
                    case GH.ERR.NO_TOKEN:
                        return i18n("Not configured yet");
                    case GH.ERR.AUTH:
                        return i18n("Token rejected — reconfigure");
                    case GH.ERR.RATE_LIMIT:
                        return i18n("Rate limited");
                    case GH.ERR.OFFLINE:
                        return i18n("Offline");
                    default:
                        return tip.b.needsYou > 0 ? i18np("%1 item needs you", "%1 items need you", tip.b.needsYou) : i18n("Nothing needs you");
                    }
                }
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        visible: tip.engine.everLoaded
    }

    Repeater {
        model: [
            {
                label: i18n("Unread"),
                value: tip.b.unread
            },
            {
                label: i18n("Failing runs"),
                value: tip.b.failing
            },
            {
                label: i18n("To review"),
                value: tip.b.toReview
            },
            {
                label: i18n("Assigned issues"),
                value: tip.b.assigned
            }
        ]

        delegate: RowLayout {
            required property var modelData

            visible: tip.engine.everLoaded
            spacing: Kirigami.Units.gridUnit
            Layout.fillWidth: true

            PlasmaComponents.Label {
                text: parent.modelData.label
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: Fmt.compact(parent.modelData.value)
                font.family: "monospace"
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: parent.modelData.value > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
        text: tip.engine.lastUpdateMs > 0 ? i18n("Updated %1 ago", Fmt.relative(new Date(tip.engine.lastUpdateMs).toISOString())) : i18n("Never updated")
    }
}
