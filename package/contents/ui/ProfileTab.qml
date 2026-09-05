// Profile: who you are on the forge, and the shape of your last year.
//
// With more than one account configured the tab shows one at a time, picked by
// the strip at the top; the engine keeps every account's bundle warm so
// switching is instant rather than a fresh round trip.
//
// When a forge or a token cannot serve a part of this, the tab still renders —
// it just says which part is missing, rather than failing whole.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "shared" as Shared
import "../code/Format.js" as Fmt
import "../code/Forge.js" as Forge
import "../code/Http.js" as Http

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

        // ── which account ───────────────────────────────────────────────────
        //
        // Only earns its row when there is a choice to make.
        Flow {
            visible: tab.engine.liveAccounts.length > 1
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: tab.engine.liveAccounts

                delegate: Shared.Pill {
                    required property var modelData

                    theme: tab.tones
                    text: Forge.displayName(modelData) + (modelData.login ? " · " + modelData.login : "")
                    tone: modelData.id === tab.engine.activeProfileId ? "accent" : "muted"
                    filled: modelData.id === tab.engine.activeProfileId
                    interactive: true
                    onClicked: tab.engine.profileAccountId = modelData.id
                }
            }
        }

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

        // ── when I ship ─────────────────────────────────────────────────────
        SectionLabel {
            visible: band.visible
            text: i18n("When I ship")
            hint: tab.engine.rhythm.length ? i18nc("mostly in the morning", "mostly %1", tab.engine.rhythm[0].name) : ""
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        }

        // Shared with hyprland/ProfilePane.qml — see shared/ActivityBand.qml.
        Shared.ActivityBand {
            id: band

            theme: tab.tones
            calendar: tab.engine.calendar
            clock: tab.engine.clock
            rhythm: tab.engine.rhythm
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2
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

        Shared.Heatmap {
            id: heatmap

            theme: tab.tones
            calendar: tab.engine.calendar
            gap: Math.max(1, Math.round(Kirigami.Units.smallSpacing / 2))
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing * 2

            PlasmaComponents.ToolTip.visible: heatmap.hoveredDay !== null
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            PlasmaComponents.ToolTip.text: heatmap.hoveredDay ? i18np("%1 contribution on %2", "%1 contributions on %2", heatmap.hoveredDay.count, heatmap.hoveredDay.date) : ""
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
        // Not every forge publishes every figure — Forgejo has no review count,
        // GitLab no "stars earned across your own repositories". A missing one
        // is dropped rather than rendered as a confident zero.
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
        ].filter(function (s) {
            return s.value !== null && s.value !== undefined;
        });
    }

    readonly property var placeholder: {
        if (tab.engine.primaryError === Http.ERR.NO_TOKEN)
            return {
                icon: "network-disconnect",
                title: i18n("Not configured"),
                body: i18n("Add a GitHub token to see your profile.")
            };
        if (tab.err === Http.ERR.FORBIDDEN)
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
