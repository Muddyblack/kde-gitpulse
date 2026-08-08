// Profile pane for the Quickshell frontend.
//
// Everything except the activity rhythm comes from one GraphQL round trip; the
// rhythm costs one extra REST call on the slow timer. Nothing here is invented:
// if a figure is not in the payload, its row is simply absent.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Layouts

import "../package/contents/code/Format.js" as Format
import "../package/contents/code/GitHub.js" as GH

QC.ScrollView {
    id: pane

    required property var theme
    required property var engine

    readonly property var p: pane.engine.profile
    readonly property var cal: pane.engine.calendar

    contentWidth: availableWidth
    clip: true

    component Section: RowLayout {
        property string title: ""
        property string hint: ""

        spacing: 6
        Layout.fillWidth: true
        Layout.topMargin: pane.theme.spacing

        Text {
            text: parent.title
            color: pane.theme.textDim
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 1
            color: pane.theme.line
        }

        Text {
            text: parent.hint
            visible: text !== ""
            color: pane.theme.textFaint
            font.pixelSize: 10
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            // Capped so a long hint shortens itself rather than running off the
            // right edge of the pane.
            Layout.maximumWidth: pane.availableWidth * 0.5
        }
    }

    readonly property var stats: pane.p ? [
        {
            label: qsTr("stars"),
            value: pane.p.starsEarned
        },
        {
            label: qsTr("commits"),
            value: pane.p.commits
        },
        {
            label: qsTr("PRs"),
            value: pane.p.pulls
        },
        {
            label: qsTr("issues"),
            value: pane.p.issues
        },
        {
            label: qsTr("reviews"),
            value: pane.p.reviews
        },
        {
            label: qsTr("repos"),
            value: pane.p.repos
        },
        {
            label: qsTr("followers"),
            value: pane.p.followers
        },
        {
            label: qsTr("orgs"),
            value: pane.p.orgs
        }
    ] : []

    ColumnLayout {
        width: pane.availableWidth
        spacing: pane.theme.spacingSmall

        // ══ identity ════════════════════════════════════════════════════════
        RowLayout {
            visible: pane.p !== null
            Layout.fillWidth: true
            spacing: pane.theme.spacing * 1.5

            RoundAvatar {
                theme: pane.theme
                login: pane.engine.viewerLogin
                source: pane.engine.avatarSource || pane.engine.avatarUrl
                Layout.alignment: Qt.AlignTop
                implicitWidth: 56
                implicitHeight: 56
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Reserve a useful, readable slice for the profile details;
                // the remaining header width is used by the compact counters.
                Layout.maximumWidth: Math.round(pane.availableWidth * 0.48)
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: pane.p ? pane.p.name : ""
                    color: pane.theme.text
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: pane.p ? "@" + pane.p.login : ""
                    color: pane.theme.accent
                    font.pixelSize: 11
                    font.family: "monospace"
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: text !== ""
                    text: pane.p ? pane.p.bio : ""
                    color: pane.theme.textDim
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: pane.subtitle
                    color: pane.theme.textFaint
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
            }

            // On normal popup widths the profile counters fit beside the
            // identity rather than taking a separate two-row block below it.
            // The full grid remains available below on very narrow panes.
            GridLayout {
                visible: pane.availableWidth >= 410
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                columns: 4
                columnSpacing: pane.theme.spacingSmall
                rowSpacing: 1

                Repeater {
                    model: pane.stats

                    delegate: ColumnLayout {
                        id: headerStat

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: Format.compact(headerStat.modelData.value)
                            color: pane.theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: headerStat.modelData.label
                            color: pane.theme.textFaint
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ══ streaks ═════════════════════════════════════════════════════════
        StreakCard {
            visible: pane.cal !== null
            theme: pane.theme
            calendar: pane.cal
            compact: true
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall
        }

        // ══ numbers ═════════════════════════════════════════════════════════
        GridLayout {
            // Keep the detail grid for a narrow popup, where the header does
            // not have enough horizontal room for the counters.
            visible: pane.p !== null && pane.availableWidth < 410
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall
            columns: 4
            columnSpacing: pane.theme.spacing
            rowSpacing: pane.theme.spacing

            Repeater {
                model: pane.stats

                delegate: ColumnLayout {
                    id: stat

                    required property var modelData

                    spacing: 0
                    Layout.fillWidth: true

                    Text {
                        text: Format.compact(stat.modelData.value)
                        color: pane.theme.text
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: stat.modelData.label
                        color: pane.theme.textFaint
                        font.pixelSize: 10
                    }
                }
            }
        }

        // ══ contributions ═══════════════════════════════════════════════════
        Section {
            visible: pane.cal !== null
            title: qsTr("Contributions")
            hint: pane.cal ? qsTr("%1 active days").arg(pane.cal.activeDays) : ""
        }

        HeatMap {
            theme: pane.theme
            calendar: pane.cal
            Layout.fillWidth: true
        }

        Text {
            visible: pane.p !== null && pane.p.privateContributions > 0
            Layout.fillWidth: true
            text: qsTr("plus %1 in private repositories").arg(pane.p ? pane.p.privateContributions : 0)
            color: pane.theme.textFaint
            font.pixelSize: 10
        }

        // ══ last 30 days ════════════════════════════════════════════════════
        Section {
            visible: pane.cal !== null && pane.cal.recent.length > 1
            title: qsTr("Last 30 days")
            hint: pane.cal ? qsTr("peak %1 · avg %2/day").arg(pane.cal.busiest).arg(pane.cal.average.toFixed(1)) : ""
        }

        TrendChart {
            theme: pane.theme
            series: pane.cal ? pane.cal.recent : []
            Layout.fillWidth: true
        }

        // ══ rhythm ══════════════════════════════════════════════════════════
        Section {
            visible: pane.engine.rhythm.length > 0
            title: qsTr("When I ship")
            hint: qsTr("public events, local time")
        }

        RhythmBars {
            theme: pane.theme
            buckets: pane.engine.rhythm
            Layout.fillWidth: true
        }

        // ══ languages ═══════════════════════════════════════════════════════
        Section {
            visible: pane.engine.languages.length > 0
            title: qsTr("Languages")
            hint: qsTr("by bytes, own repositories")
        }

        Rectangle {
            visible: pane.engine.languages.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 8
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.07)
            clip: true

            Row {
                anchors.fill: parent

                Repeater {
                    model: pane.engine.languages

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width * modelData.share / 100
                        height: parent.height
                        color: modelData.color && modelData.color.length ? modelData.color : pane.theme.textDim
                    }
                }
            }
        }

        Flow {
            visible: pane.engine.languages.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: pane.theme.spacing
            spacing: pane.theme.spacing

            Repeater {
                model: pane.engine.languages

                delegate: Row {
                    required property var modelData

                    spacing: 4

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: parent.modelData.color && parent.modelData.color.length ? parent.modelData.color : pane.theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.name + " " + Math.round(parent.modelData.share) + "%"
                        color: pane.theme.textDim
                        font.pixelSize: 9
                    }
                }
            }
        }

        // ══ nothing to show ═════════════════════════════════════════════════
        Text {
            visible: pane.p === null
            Layout.fillWidth: true
            Layout.topMargin: 40
            text: pane.engine.primaryError === GH.ERR.NO_TOKEN ? qsTr("Add a GitHub token to see your profile.") : pane.engine.errorFor("profile") === GH.ERR.FORBIDDEN ? qsTr("GraphQL refused this token. Add a classic token with read:user as the Profile token in settings.") : qsTr("Loading profile…")
            color: pane.theme.textDim
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Item {
            Layout.fillHeight: true
        }
    }

    readonly property string subtitle: {
        if (!pane.p)
            return "";
        var bits = [];
        if (pane.p.company)
            bits.push(pane.p.company);
        if (pane.p.location)
            bits.push(pane.p.location);
        if (pane.p.createdAt)
            bits.push(qsTr("joined %1 ago").arg(Format.relative(pane.p.createdAt)));
        return bits.join(" · ");
    }
}
