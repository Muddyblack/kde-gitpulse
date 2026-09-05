// Profile pane for the Quickshell frontend.
//
// With more than one account configured this shows one at a time, picked by
// the strip at the top. Nothing here is invented: if a figure is not in the
// payload — and no forge publishes all of them — its cell is simply absent.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Layouts

import "../package/contents/ui/shared" as Shared
import "../package/contents/code/Format.js" as Format
import "../package/contents/code/Forge.js" as Forge
import "../package/contents/code/Http.js" as Http

QC.ScrollView {
    id: pane

    required property var theme
    required property var engine

    readonly property var p: pane.engine.profile
    readonly property var cal: pane.engine.calendar

    contentWidth: availableWidth
    contentHeight: content.implicitHeight
    clip: true

    component Section: RowLayout {
        property string title: ""
        property string hint: ""

        spacing: 6
        Layout.fillWidth: true
        Layout.topMargin: pane.theme.spacingSmall + 2

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

    readonly property var stats: (pane.p ? [
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
        ] : []).filter(function (s) {
        return s.value !== null && s.value !== undefined;
    })

    ColumnLayout {
        id: content

        width: pane.availableWidth
        spacing: pane.theme.spacingSmall

        // ══ which account ═══════════════════════════════════════════════════
        //
        // Only earns its row when there is a choice to make.
        Flow {
            visible: pane.engine.liveAccounts.length > 1
            Layout.fillWidth: true
            Layout.bottomMargin: pane.theme.spacingSmall
            spacing: pane.theme.spacingSmall

            Repeater {
                model: pane.engine.liveAccounts

                delegate: Shared.Pill {
                    required property var modelData

                    theme: pane.theme
                    text: Forge.displayName(modelData) + (modelData.login ? " · " + modelData.login : "")
                    tone: modelData.id === pane.engine.activeProfileId ? "accent" : "muted"
                    filled: modelData.id === pane.engine.activeProfileId
                    interactive: true
                    onClicked: pane.engine.profileAccountId = modelData.id
                }
            }
        }

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

        // ══ when I ship, and the streaks ════════════════════════════════════
        Section {
            visible: band.visible
            title: qsTr("When I ship")
            hint: pane.engine.rhythm.length ? qsTr("mostly %1").arg(pane.engine.rhythm[0].name) : ""
        }

        Shared.ActivityBand {
            id: band

            theme: pane.theme
            calendar: pane.cal
            clock: pane.engine.clock
            rhythm: pane.engine.rhythm
            Layout.fillWidth: true
            Layout.topMargin: pane.theme.spacingSmall
        }

        // ══ contributions ═══════════════════════════════════════════════════
        Section {
            visible: pane.cal !== null
            title: qsTr("Contributions")
            hint: pane.cal ? qsTr("%1 active days").arg(pane.cal.activeDays) : ""
        }

        Shared.Heatmap {
            id: heatmap

            theme: pane.theme
            calendar: pane.cal
            Layout.fillWidth: true

            QC.ToolTip.visible: heatmap.hoveredDay !== null
            QC.ToolTip.delay: 400
            QC.ToolTip.text: heatmap.hoveredDay ? heatmap.hoveredDay.count + qsTr(" on ") + heatmap.hoveredDay.date : ""
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

        Shared.TrendChart {
            theme: pane.theme
            series: pane.cal ? pane.cal.recent : []
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
            color: pane.theme.track
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
            spacing: 6

            Repeater {
                model: pane.engine.languages

                delegate: RowLayout {
                    required property var modelData

                    spacing: 4

                    Rectangle {
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 3.5
                        color: modelData.color && modelData.color.length ? modelData.color : pane.theme.textDim
                    }

                    Text {
                        text: modelData.name + " " + Math.round(modelData.share) + "%"
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
            text: pane.engine.primaryError === Http.ERR.NO_TOKEN ? qsTr("Add a GitHub token to see your profile.") : pane.engine.errorFor("profile") === Http.ERR.FORBIDDEN ? qsTr("GraphQL refused this token. Add a classic token with read:user as the Profile token in settings.") : qsTr("Loading profile…")
            color: pane.theme.textDim
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Item {
            visible: pane.p !== null
            implicitHeight: pane.theme.spacing
        }

        Item {
            visible: pane.p === null
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
