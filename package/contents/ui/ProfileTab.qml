// Profile: who you are on GitHub, and the shape of your last year.
//
// Everything here arrives in a single GraphQL round trip. When the token
// cannot do GraphQL the tab still renders — it just says which part is
// missing, rather than failing whole.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "shared" as Shared
import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

PlasmaComponents.ScrollView {
    id: tab

    required property var engine
    required property var host

    readonly property var p: tab.engine.profile
    readonly property string err: tab.engine.errorFor("profile")
    readonly property Tones tones: Tones {}

    contentWidth: availableWidth
    // Explicit, not left to auto-detection: with every section this tab now
    // has (streak summary, trend chart, rhythm bars, languages), content
    // reliably runs taller than the popup, and the ScrollView needs a real
    // contentHeight to know there is anything to scroll to.
    contentHeight: content.implicitHeight

    ColumnLayout {
        id: content

        width: tab.availableWidth
        spacing: Kirigami.Units.smallSpacing * 2

        // ── identity ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: 0
            spacing: Kirigami.Units.smallSpacing * 2
            visible: tab.p !== null

            Avatar {
                login: tab.engine.viewerLogin
                source: tab.engine.avatarSource || tab.engine.avatarUrl
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaExtras.Heading {
                    level: 4
                    text: tab.p ? tab.p.name : ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: tab.p ? "@" + tab.p.login : ""
                    font.family: "monospace"
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: tab.p ? tab.p.bio : ""
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: tab.subtitle
                    visible: text !== ""
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.Wrap
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true
                }
            }
        }

        // ── numbers ─────────────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            visible: tab.p !== null
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Math.round(Kirigami.Units.smallSpacing * 1.25)

            Repeater {
                model: tab.stats

                delegate: StatTile {
                    required property var modelData

                    iconName: modelData.icon
                    label: modelData.label
                    value: modelData.value
                    tone: modelData.tone || "muted"
                    Layout.fillWidth: true
                }
            }
        }

        // ── contributions ───────────────────────────────────────────────────
        SectionLabel {
            visible: tab.engine.calendar !== null
            text: tab.engine.calendar ? i18np("%1 contribution in the last year", "%1 contributions in the last year", tab.engine.calendar.total) : ""
            hint: tab.engine.calendar && tab.engine.calendar.activeDays > 0 ? i18np("%1 active day", "%1 active days", tab.engine.calendar.activeDays) : ""
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // Compact streak summary: total contributions · current streak · longest.
        // Mirrors the "compact" mode of hyprland/StreakCard.qml without the
        // Quickshell-specific theme object — uses Kirigami palette instead.
        RowLayout {
            visible: tab.engine.calendar !== null
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 2

            Repeater {
                model: [
                    {
                        value: tab.engine.calendar ? tab.engine.calendar.total.toLocaleString(Qt.locale(), "f", 0) : "0",
                        label: i18n("contributions"),
                        accent: true
                    },
                    {
                        value: tab.engine.calendar ? tab.engine.calendar.current : "0",
                        label: i18n("day streak"),
                        accent: false
                    },
                    {
                        value: tab.engine.calendar ? tab.engine.calendar.streak : "0",
                        label: i18n("longest streak"),
                        accent: false
                    }
                ]

                delegate: RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Math.round(Kirigami.Units.smallSpacing * 0.75)

                    PlasmaExtras.Heading {
                        level: 3
                        text: parent.modelData.value
                        color: parent.modelData.accent ? tab.tones.accent : Kirigami.Theme.textColor
                    }

                    PlasmaComponents.Label {
                        text: parent.modelData.label
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        ContribGraph {
            calendar: tab.engine.calendar
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        PlasmaComponents.Label {
            visible: tab.p !== null && tab.p.privateContributions > 0
            text: i18np("plus %1 contribution in private repositories", "plus %1 contributions in private repositories", tab.p ? tab.p.privateContributions : 0)
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // ── last 30 days ────────────────────────────────────────────────────
        SectionLabel {
            visible: tab.engine.calendar !== null && tab.engine.calendar.recent.length > 1
            text: i18n("Last 30 days")
            hint: tab.engine.calendar ? i18nc("peak N · avg N.N/day", "peak %1 · avg %2/day", tab.engine.calendar.busiest, tab.engine.calendar.average.toFixed(1)) : ""
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // Shared with hyprland/ProfilePane.qml — see shared/TrendChart.qml.
        Shared.TrendChart {
            theme: tab.tones
            series: tab.engine.calendar ? tab.engine.calendar.recent : []
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // ── when I ship ─────────────────────────────────────────────────────
        SectionLabel {
            visible: tab.engine.rhythm.length > 0
            text: i18n("When I ship")
            hint: i18n("public events, local time")
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // Shared with hyprland/ProfilePane.qml — see shared/RhythmBars.qml.
        Shared.RhythmBars {
            theme: tab.tones
            buckets: tab.engine.rhythm
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // ── languages ───────────────────────────────────────────────────────
        SectionLabel {
            visible: tab.engine.languages.length > 0
            text: i18n("Languages")
            hint: i18n("by bytes, own repositories")
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        LanguageBar {
            languages: tab.engine.languages
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
        }

        Item {
            Layout.fillHeight: true
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 3
        visible: tab.p === null

        iconName: tab.placeholder.icon
        text: tab.placeholder.title
        explanation: tab.placeholder.body
    }

    readonly property string subtitle: {
        if (!tab.p)
            return "";
        var bits = [];
        if (tab.p.company)
            bits.push(tab.p.company);
        if (tab.p.location)
            bits.push(tab.p.location);
        if (tab.p.createdAt)
            bits.push(i18n("joined %1 ago", Fmt.relative(tab.p.createdAt)));
        return bits.join(" · ");
    }

    readonly property var stats: {
        if (!tab.p)
            return [];
        return [
            {
                icon: "rating",
                label: i18n("stars earned"),
                value: tab.p.starsEarned,
                tone: "neutral"
            },
            {
                icon: "vcs-commit",
                label: i18n("commits"),
                value: tab.p.commits,
                tone: "positive"
            },
            {
                icon: "vcs-merge-request",
                label: i18n("pull requests"),
                value: tab.p.pulls,
                tone: "accent"
            },
            {
                icon: "view-task",
                label: i18n("issues"),
                value: tab.p.issues,
                tone: "muted"
            },
            {
                icon: "checkmark",
                label: i18n("reviews"),
                value: tab.p.reviews,
                tone: "positive"
            },
            {
                icon: "folder-git",
                label: i18n("repositories"),
                value: tab.p.repos,
                tone: "muted"
            },
            {
                icon: "system-users",
                label: i18n("followers"),
                value: tab.p.followers,
                tone: "muted"
            },
            {
                icon: "user-group-new",
                label: i18n("organisations"),
                value: tab.p.orgs,
                tone: "muted"
            }
        ];
    }

    readonly property var placeholder: {
        if (tab.engine.primaryError === GH.ERR.NO_TOKEN)
            return {
                icon: "network-disconnect",
                title: i18n("Not configured"),
                body: i18n("Add a GitHub token to see your profile.")
            };
        if (tab.err === GH.ERR.FORBIDDEN)
            return {
                icon: "object-locked",
                title: i18n("GraphQL not permitted"),
                body: i18n("The profile view needs a classic token with read:user. Fine-grained tokens cannot read the contribution calendar.")
            };
        if (tab.err !== "")
            return {
                icon: "dialog-error",
                title: i18n("Could not load the profile"),
                body: tab.engine.messageFor("profile")
            };
        return {
            icon: "state-sync",
            title: i18n("Loading…"),
            body: i18n("Fetching your profile from GitHub.")
        };
    }
}
