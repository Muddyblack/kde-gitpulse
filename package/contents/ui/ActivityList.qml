// The scrolling list behind Inbox, Actions, Pulls and Issues.
//
// Four tabs, one component: they differ only in which query filled the
// section, which is the whole point of normalising everything in Contract.js.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "../code/Contract.js" as Contract
import "../code/GitHub.js" as GH

Item {
    id: view

    required property var engine
    required property var host
    required property string tab
    required property string chip
    required property string query
    required property bool grouped

    signal clearFilters

    /** Only one drawer open at a time, the way Plasma's own list items behave. */
    property string expandedId: ""

    /**
     * Section headers. Grouping by repository wins when asked for; otherwise
     * the inbox gets a "new since you last looked" divider, which is the only
     * grouping that tells you something you did not already know.
     */
    readonly property string sectionRole: view.grouped ? "repo" : (view.tab === "inbox" && view.query === "" ? "freshness" : "")

    /** Items after chips, search and sorting — exactly what is on screen. */
    readonly property var visibleItems: {
        var raw = view.engine.sections[view.tab] || [];
        var out = Contract.sortItems(Contract.search(Contract.applyChip(raw, view.chip), view.query), view.tab);
        if (view.sectionRole === "freshness") {
            // Annotating the item is cheaper than copying the list, and these
            // objects are rebuilt from scratch on every poll anyway.
            var cutoff = Date.now() - 60 * 60 * 1000;
            for (var i = 0; i < out.length; i++)
                out[i].freshness = (out[i].unread && Date.parse(out[i].updatedAt) >= cutoff) ? "fresh" : "older";
        }
        return out;
    }

    function open(item, keepOpen) {
        if (!item)
            return;
        view.host.openUrl(item.url);
        view.engine.markRead(item);
        if (!keepOpen)
            view.host.expanded = false;
    }

    Component.onCompleted: list.forceActiveFocus()

    PlasmaComponents.ScrollView {
        anchors.fill: parent
        visible: list.count > 0

        ListView {
            id: list

            model: view.visibleItems
            currentIndex: -1
            keyNavigationEnabled: true
            keyNavigationWraps: true
            highlightMoveDuration: Kirigami.Units.shortDuration
            clip: true
            focus: true

            section.property: view.sectionRole
            section.criteria: ViewSection.FullString
            section.delegate: SectionHeader {
                required property string section

                width: ListView.view.width
                text: view.sectionRole === "freshness" ? (section === "fresh" ? i18n("New since you last looked") : i18n("Earlier")) : section
                accented: view.sectionRole === "freshness" && section === "fresh"
            }

            delegate: ActivityRow {
                required property var modelData
                required property int index

                width: ListView.view.width
                item: modelData
                engine: view.engine
                selected: list.currentIndex === index
                expanded: view.expandedId === modelData.id

                onActivated: keepOpen => view.open(modelData, keepOpen)
                onOpenUrlRequested: url => view.host.openUrl(url)
                onFocusRequested: list.currentIndex = index
                onToggleExpanded: view.expandedId = (view.expandedId === modelData.id ? "" : modelData.id)
            }

            Keys.onPressed: event => {
                var item = list.currentIndex >= 0 ? view.visibleItems[list.currentIndex] : null;
                if (!item)
                    return;
                switch (event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    view.open(item, (event.modifiers & Qt.ControlModifier) !== 0);
                    event.accepted = true;
                    break;
                case Qt.Key_Space:
                    view.expandedId = (view.expandedId === item.id ? "" : item.id);
                    event.accepted = true;
                    break;
                case Qt.Key_M:
                    if (!(event.modifiers & Qt.ShiftModifier)) {
                        view.engine.markRead(item);
                        event.accepted = true;
                    }
                    break;
                }
            }
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 3
        visible: list.count === 0

        iconName: view.placeholder.icon
        text: view.placeholder.title
        explanation: view.placeholder.body

        helpfulAction: Kirigami.Action {
            text: i18n("Clear filter")
            icon.name: "edit-clear"
            visible: view.query !== "" || view.chip !== "all"
            onTriggered: view.clearFilters()
        }
    }

    readonly property var placeholder: {
        var slot = (view.tab === "pulls" || view.tab === "issues") ? "search" : view.tab;
        var err = view.engine.errorFor(slot);
        if (view.engine.primaryError === GH.ERR.NO_TOKEN)
            return {
                icon: "network-disconnect",
                title: i18n("Not configured"),
                body: i18n("Add a read-only GitHub token in the widget settings.")
            };
        if (err === GH.ERR.FORBIDDEN)
            return {
                icon: "object-locked",
                title: i18n("Token lacks access"),
                body: i18n("This tab needs a scope the current token does not have.")
            };
        if (view.query !== "")
            return {
                icon: "search",
                title: i18n("No matches"),
                body: i18n("Nothing in this tab matches “%1”.", view.query)
            };
        if (!view.engine.everLoaded)
            return {
                icon: "state-sync",
                title: i18n("Syncing…"),
                body: i18n("Fetching your activity from GitHub.")
            };
        if (view.tab === "inbox")
            return {
                icon: "checkmark",
                title: i18n("Inbox zero"),
                body: i18n("No unread notifications. The tray icon has already stepped aside.")
            };
        return {
            icon: "checkmark",
            title: i18n("Nothing here"),
            body: i18n("Nothing in this tab matches the current filter.")
        };
    }
}
