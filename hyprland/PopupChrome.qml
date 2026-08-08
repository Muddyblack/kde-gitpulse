// Everything inside the popup frame: header, search, tabs, chips, content,
// footer. Split out of GitpulseShell so the shell stays about wiring.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Layouts

import "../package/contents/code/Contract.js" as Contract
import "../package/contents/code/Format.js" as Format
import "../package/contents/code/GitHub.js" as GH
import "Icons.js" as Glyphs

Item {
    id: chrome

    required property var theme
    required property var engine
    required property var tabs
    required property string currentTab
    required property bool settingsVisible

    property string query: ""
    property bool searchActive: false
    property bool grouped: false
    property string expandedId: ""
    property var chipFor: ({})

    signal tabPicked(string id)
    signal settingsToggled
    signal closeRequested
    signal openUrl(string url)

    readonly property string chip: chrome.chipFor[chrome.currentTab] || "all"
    readonly property bool listTab: ["inbox", "actions", "pulls", "issues"].indexOf(chrome.currentTab) >= 0

    function setChip(id) {
        var next = {};
        for (var k in chrome.chipFor)
            next[k] = chrome.chipFor[k];
        next[chrome.currentTab] = id;
        chrome.chipFor = next;
    }

    readonly property var chipDefs: {
        switch (chrome.currentTab) {
        case "inbox":
            return [
                {
                    id: "all",
                    label: qsTr("All")
                },
                {
                    id: "needs",
                    label: qsTr("Needs you")
                },
                {
                    id: "mention",
                    label: qsTr("Mentions")
                },
                {
                    id: "unread",
                    label: qsTr("Unread")
                }
            ];
        case "actions":
            return [
                {
                    id: "all",
                    label: qsTr("All")
                },
                {
                    id: "failed",
                    label: qsTr("Failed")
                },
                {
                    id: "active",
                    label: qsTr("Running")
                }
            ];
        case "pulls":
            return [
                {
                    id: "all",
                    label: qsTr("All")
                },
                {
                    id: "review",
                    label: qsTr("Review requested")
                },
                {
                    id: "mine",
                    label: qsTr("Mine")
                }
            ];
        case "issues":
            return [
                {
                    id: "all",
                    label: qsTr("All")
                },
                {
                    id: "assigned",
                    label: qsTr("Assigned to me")
                },
                {
                    id: "mine",
                    label: qsTr("Opened by me")
                }
            ];
        default:
            return [];
        }
    }

    readonly property var rawItems: chrome.engine.sections[chrome.currentTab] || []
    readonly property var visibleItems: {
        var out = Contract.sortItems(Contract.search(Contract.applyChip(chrome.rawItems, chrome.chip), chrome.query), chrome.currentTab);
        if (chrome.grouped)
            return out;
        if (chrome.currentTab === "inbox" && chrome.query === "") {
            var cutoff = Date.now() - 3600000;
            for (var i = 0; i < out.length; i++)
                out[i].bucket = (out[i].unread && Date.parse(out[i].updatedAt) >= cutoff) ? "fresh" : "older";
        }
        return out;
    }
    readonly property string sectionRole: chrome.grouped ? "repo" : (chrome.currentTab === "inbox" && chrome.query === "" ? "bucket" : "")

    ColumnLayout {
        anchors.fill: parent
        spacing: chrome.theme.spacing

        // ══ header ══════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: chrome.theme.spacing * 1.25

            RoundAvatar {
                theme: chrome.theme
                login: chrome.engine.viewerLogin
                source: chrome.engine.avatarSource || chrome.engine.avatarUrl
                implicitWidth: 32
                implicitHeight: 32
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Gitpulse"
                    color: chrome.theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: chrome.subtitle
                    textFormat: Text.StyledText
                    color: chrome.theme.textDim
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            IconButton {
                theme: chrome.theme
                iconName: "search"
                tip: qsTr("Filter")
                active: chrome.searchActive
                onClicked: {
                    chrome.searchActive = !chrome.searchActive;
                    if (chrome.searchActive)
                        field.forceActiveFocus();
                    else
                        chrome.query = "";
                }
            }

            IconButton {
                theme: chrome.theme
                iconName: "group"
                tip: qsTr("Group by repository")
                active: chrome.grouped
                onClicked: chrome.grouped = !chrome.grouped
            }

            IconButton {
                theme: chrome.theme
                iconName: "refresh"
                tip: qsTr("Refresh")
                onClicked: chrome.engine.refreshAll(false)
            }

            IconButton {
                theme: chrome.theme
                iconName: "gear"
                tip: qsTr("Settings")
                active: chrome.settingsVisible
                onClicked: chrome.settingsToggled()
            }

            IconButton {
                theme: chrome.theme
                iconName: "close"
                tip: qsTr("Close")
                onClicked: chrome.closeRequested()
            }
        }

        // ══ search ══════════════════════════════════════════════════════════
        Rectangle {
            visible: chrome.searchActive && !chrome.settingsVisible
            Layout.fillWidth: true
            implicitHeight: 30
            radius: chrome.theme.radiusSmall
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: field.activeFocus ? chrome.theme.accent : chrome.theme.line

            Icon {
                id: mag

                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                name: "search"
                color: chrome.theme.textFaint
            }

            QC.TextField {
                id: field

                anchors.left: mag.right
                anchors.right: clearBtn.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 7
                text: chrome.query
                placeholderText: qsTr("Filter titles and repositories…")
                color: chrome.theme.text
                placeholderTextColor: chrome.theme.textFaint
                font.pixelSize: 12
                background: null
                onTextChanged: chrome.query = text
                Keys.onEscapePressed: {
                    if (chrome.query !== "")
                        text = "";
                    else
                        chrome.searchActive = false;
                }
            }

            IconButton {
                id: clearBtn

                theme: chrome.theme
                iconName: "close"
                size: 20
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    field.text = "";
                    chrome.searchActive = false;
                }
            }
        }

        // ══ tabs ════════════════════════════════════════════════════════════
        Item {
            visible: !chrome.settingsVisible
            Layout.fillWidth: true
            implicitHeight: 34

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: chrome.theme.line
            }

            Row {
                id: tabRow

                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: chrome.tabs

                    delegate: Item {
                        id: tab

                        required property var modelData

                        readonly property bool active: chrome.currentTab === modelData.id
                        readonly property int need: chrome.engine.badge.perTab[modelData.id] || 0
                        readonly property int total: (chrome.engine.sections[modelData.id] || []).length

                        // The selected tab earns the room its label needs; the
                        // rest are a glyph and a count.
                        width: tab.active ? Math.max(96, tabContent.implicitWidth + 22) : (tabRow.width - Math.max(96, tabContent.implicitWidth + 22)) / Math.max(1, chrome.tabs.length - 1)
                        height: parent.height

                        Behavior on width {
                            NumberAnimation {
                                duration: chrome.theme.longDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Row {
                            id: tabContent

                            anchors.centerIn: parent
                            spacing: 5

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 15
                                height: 15
                                name: Glyphs.forTab(tab.modelData.id)
                                color: tab.active ? chrome.theme.text : chrome.theme.textDim
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: tab.active
                                text: tab.modelData.label
                                color: chrome.theme.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: tab.need > 0 || tab.total > 0
                                implicitWidth: Math.max(height, pipText.implicitWidth + 8)
                                implicitHeight: 15
                                radius: 7.5
                                color: tab.need > 0 ? chrome.theme.accent : Qt.rgba(1, 1, 1, 0.09)

                                Text {
                                    id: pipText

                                    anchors.centerIn: parent
                                    text: tab.need > 0 ? tab.need : tab.total
                                    color: tab.need > 0 ? chrome.theme.accentText : chrome.theme.textDim
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Rectangle {
                            visible: tab.active
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8
                            height: 2
                            radius: 1
                            color: chrome.theme.accent
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: chrome.tabPicked(tab.modelData.id)
                        }
                    }
                }
            }
        }

        // ══ chips ═══════════════════════════════════════════════════════════
        Flow {
            visible: !chrome.settingsVisible && chrome.listTab && chrome.chipDefs.length > 0
            Layout.fillWidth: true
            spacing: chrome.theme.spacingSmall * 1.5

            Repeater {
                model: chrome.chipDefs

                delegate: Chip {
                    id: chipItem

                    required property var modelData

                    readonly property int n: Contract.applyChip(chrome.rawItems, modelData.id).length

                    theme: chrome.theme
                    text: chipItem.modelData.label
                    count: chipItem.n
                    active: chrome.chip === chipItem.modelData.id
                    enabled: chipItem.n > 0 || chipItem.modelData.id === "all" || chipItem.active
                    onClicked: chrome.setChip(chipItem.modelData.id)
                }
            }
        }

        // ══ content ═════════════════════════════════════════════════════════
        Loader {
            id: pane

            visible: !chrome.settingsVisible
            Layout.fillWidth: true
            Layout.fillHeight: true

            sourceComponent: {
                switch (chrome.currentTab) {
                case "profile":
                    return profilePane;
                case "copilot":
                    return copilotPane;
                case "status":
                    return statusPane;
                default:
                    return listPane;
                }
            }
        }

        // ══ footer ══════════════════════════════════════════════════════════
        RowLayout {
            visible: !chrome.settingsVisible
            Layout.fillWidth: true
            spacing: chrome.theme.spacing

            Rectangle {
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: chrome.engine.primaryError === "" ? chrome.theme.positive : chrome.engine.primaryError === GH.ERR.OFFLINE ? chrome.theme.negative : chrome.theme.neutral
            }

            Text {
                Layout.fillWidth: true
                text: chrome.freshness
                color: chrome.theme.textFaint
                font.pixelSize: 11
                font.family: "monospace"
                elide: Text.ElideRight
            }

            Rectangle {
                visible: chrome.engine.rateLimit > 0
                implicitWidth: 34
                implicitHeight: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    readonly property real frac: chrome.engine.rateLimit > 0 ? Math.max(0, chrome.engine.rateRemaining) / chrome.engine.rateLimit : 0

                    width: Math.max(parent.height, parent.width * frac)
                    height: parent.height
                    radius: 2
                    color: frac <= 0.02 ? chrome.theme.negative : frac < 0.25 ? chrome.theme.neutral : chrome.theme.positive
                }
            }

            Text {
                visible: chrome.engine.rateLimit > 0
                text: Format.compact(chrome.engine.rateRemaining)
                color: chrome.theme.textFaint
                font.pixelSize: 11
                font.family: "monospace"
            }

            ActionButton {
                theme: chrome.theme
                iconName: "mailRead"
                text: qsTr("Mark all read")
                visible: chrome.engine.badge.unread > 0
                onClicked: chrome.engine.markAllRead(null)
            }
        }
    }

    // ── panes ───────────────────────────────────────────────────────────────

    Component {
        id: listPane

        ListView {
            id: list

            clip: true
            spacing: 3
            model: chrome.visibleItems

            section.property: chrome.sectionRole
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                required property string section

                width: ListView.view.width
                implicitHeight: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 2
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.sectionRole === "bucket" ? (section === "fresh" ? qsTr("NEW SINCE YOU LAST LOOKED") : qsTr("EARLIER")) : section
                        color: chrome.sectionRole === "bucket" && section === "fresh" ? chrome.theme.accent : chrome.theme.textFaint
                        font.pixelSize: 10
                        font.family: "monospace"
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }
                }
            }

            delegate: Column {
                id: entry

                required property var modelData

                width: ListView.view.width
                spacing: 3

                ActivityItem {
                    width: parent.width
                    item: entry.modelData
                    theme: chrome.theme
                    engine: chrome.engine
                    expanded: chrome.expandedId === entry.modelData.id

                    onActivated: keepOpen => {
                        chrome.openUrl(entry.modelData.url);
                        chrome.engine.markRead(entry.modelData);
                    }
                    onDismissed: chrome.engine.markRead(entry.modelData)
                    onToggleExpanded: chrome.expandedId = (chrome.expandedId === entry.modelData.id ? "" : entry.modelData.id)
                }

                RowDrawer {
                    width: parent.width
                    visible: chrome.expandedId === entry.modelData.id
                    theme: chrome.theme
                    item: entry.modelData
                    engine: chrome.engine

                    onOpenUrl: url => chrome.openUrl(url)
                    onDone: chrome.expandedId = ""
                }
            }

            Text {
                anchors.centerIn: parent
                width: list.width - 60
                visible: list.count === 0
                text: chrome.emptyText
                color: chrome.theme.textDim
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }

    Component {
        id: profilePane

        ProfilePane {
            theme: chrome.theme
            engine: chrome.engine
        }
    }

    Component {
        id: copilotPane

        CopilotPane {
            theme: chrome.theme
            engine: chrome.engine
        }
    }

    Component {
        id: statusPane

        StatusPane {
            theme: chrome.theme
            engine: chrome.engine
        }
    }

    // ── strings ─────────────────────────────────────────────────────────────

    readonly property string subtitle: {
        var accentHex = chrome.theme.accent.toString();
        switch (chrome.engine.primaryError) {
        case GH.ERR.NO_TOKEN:
            return qsTr("not configured");
        case GH.ERR.AUTH:
            return qsTr("token rejected");
        case GH.ERR.RATE_LIMIT:
            return qsTr("rate limited");
        case GH.ERR.OFFLINE:
            return qsTr("offline");
        }
        var b = chrome.engine.badge;
        var who = chrome.engine.viewerLogin;
        if (b.needsYou === 0)
            return who ? who + qsTr(" · nothing needs you") : qsTr("nothing needs you");
        var core = "<font color=\"" + accentHex + "\"><b>" + b.needsYou + qsTr(" need you") + "</b></font>";
        var extra = Math.max(0, b.unread - b.perTab.inbox);
        return who + " · " + core + (extra > 0 ? " · " + extra + qsTr(" more") : "");
    }

    readonly property string freshness: {
        if (chrome.engine.primaryError === GH.ERR.NO_TOKEN)
            return qsTr("not configured");
        if (chrome.engine.lastUpdateMs === 0)
            return qsTr("waiting for first sync");
        return qsTr("%1 ago").arg(Format.relative(new Date(chrome.engine.lastUpdateMs).toISOString()));
    }

    readonly property string emptyText: {
        if (chrome.engine.primaryError === GH.ERR.NO_TOKEN)
            return qsTr("Add a GitHub token in settings to start syncing.");
        if (!chrome.engine.everLoaded)
            return qsTr("Syncing…");
        if (chrome.query !== "")
            return qsTr("Nothing matches “%1”.").arg(chrome.query);
        return qsTr("Nothing here.");
    }
}
