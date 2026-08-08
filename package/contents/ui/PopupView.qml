// Full representation: header, tabs, one content pane, footer.
//
// Assembly only — every pane is its own file and every filtering decision is
// in Contract.js.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "../code/Contract.js" as Contract

PlasmaExtras.Representation {
    id: popup

    required property var engine
    required property var host

    property string query: ""
    property bool searchActive: false
    property bool grouped: Plasmoid.configuration.groupByRepo
    /** Chip selection is remembered per tab, so switching back is not a reset. */
    property var chips: ({})

    readonly property string tab: popup.host.currentTab
    readonly property string chip: popup.chips[popup.tab] || "all"
    readonly property bool listTab: ["inbox", "actions", "pulls", "issues"].indexOf(popup.tab) >= 0

    function setChip(id) {
        var next = {};
        for (var k in popup.chips)
            next[k] = popup.chips[k];
        next[popup.tab] = id;
        popup.chips = next;
    }

    function clearSearch() {
        popup.query = "";
        popup.searchActive = false;
    }

    function beginMarkAllRead() {
        toast.begin(i18np("Marked %1 notification as read", "Marked %1 notifications as read", popup.engine.badge.unread));
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 30

    collapseMarginsHint: true
    focus: true

    // Only painted in "glass" mode; in the other two Plasma's own dialog
    // background is doing the job and this would double up on it.
    background: Rectangle {
        readonly property bool glass: Plasmoid.configuration.surfaceMode === "glass"

        visible: glass
        radius: Kirigami.Units.cornerRadius * 2
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, Plasmoid.configuration.popupOpacity)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.13)

        // The lit top edge is what sells glass: real frosted surfaces catch
        // light where they meet the bezel.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            anchors.topMargin: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.22)
        }
    }

    header: ColumnLayout {
        spacing: 0

        HeaderBar {
            engine: popup.engine
            searchActive: popup.searchActive
            grouped: popup.grouped
            Layout.fillWidth: true

            onToggleSearch: {
                popup.searchActive = !popup.searchActive;
                if (popup.searchActive)
                    searchField.forceActiveFocus();
                else
                    popup.query = "";
            }
            onToggleGroup: {
                popup.grouped = !popup.grouped;
                Plasmoid.configuration.groupByRepo = popup.grouped;
            }
            onRefresh: popup.engine.refreshAll(true)
            onConfigure: Plasmoid.internalAction("configure").trigger()
        }

        Banner {
            engine: popup.engine
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            onConfigure: Plasmoid.internalAction("configure").trigger()
        }

        PlasmaExtras.SearchField {
            id: searchField

            visible: popup.searchActive
            placeholderText: i18n("Filter titles and repositories…")
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            onTextChanged: popup.query = text
            onAccepted: popup.query = text

            Keys.onEscapePressed: {
                if (popup.query !== "")
                    text = "";
                else
                    popup.clearSearch();
                popup.forceActiveFocus();
            }
        }

        TabStrip {
            id: tabStrip

            tabs: popup.host.tabs
            engine: popup.engine
            current: popup.tab
            Layout.fillWidth: true
            onSelected: id => popup.host.currentTab = id
        }

        FilterChips {
            visible: popup.listTab && popup.engine.everLoaded
            items: popup.engine.sections[popup.tab] || []
            tab: popup.tab
            current: popup.chip
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            onPicked: id => popup.setChip(id)
        }
    }

    footer: FooterBar {
        engine: popup.engine
        onMarkAllRead: popup.beginMarkAllRead()
    }

    contentItem: Item {
        Loader {
            id: pane

            anchors.fill: parent
            sourceComponent: {
                switch (popup.tab) {
                case "profile":
                    return profilePane;
                case "copilot":
                    return copilotPane;
                case "status":
                    return statusPane;
                default:
                    return activityPane;
                }
            }
        }

        UndoToast {
            id: toast

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Kirigami.Units.smallSpacing
            windowSec: Plasmoid.configuration.undoWindowSec
            z: 10

            onCommitted: popup.engine.markAllRead(null)
            onUndone: popup.engine.refreshInbox()
        }

        ShortcutSheet {
            id: sheet

            anchors.fill: parent
            visible: false
            z: 20
            onDismissed: {
                sheet.visible = false;
                popup.forceActiveFocus();
            }
        }
    }

    Component {
        id: activityPane

        ActivityList {
            engine: popup.engine
            host: popup.host
            tab: popup.tab
            chip: popup.chip
            query: popup.query
            grouped: popup.grouped

            onClearFilters: {
                popup.setChip("all");
                popup.clearSearch();
            }
        }
    }

    Component {
        id: profilePane

        ProfileTab {
            engine: popup.engine
            host: popup.host
        }
    }

    Component {
        id: copilotPane

        CopilotTab {
            engine: popup.engine
            host: popup.host
        }
    }

    Component {
        id: statusPane

        StatusTab {
            engine: popup.engine
            host: popup.host
        }
    }

    // ── keyboard ────────────────────────────────────────────────────────────
    //
    // Arrow keys are deliberately not handled here: the list has focus and
    // ListView already does the right thing with them. Everything below is
    // what the list does not claim.
    Keys.onPressed: event => {
        if (event.modifiers & Qt.AltModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var i = event.key - Qt.Key_1;
            if (i < popup.host.tabs.length) {
                popup.host.currentTab = popup.host.tabs[i].id;
                event.accepted = true;
            }
            return;
        }
        switch (event.key) {
        case Qt.Key_Escape:
            if (popup.query !== "" || popup.searchActive) {
                popup.clearSearch();
                event.accepted = true;
            }
            break;
        case Qt.Key_Slash:
            popup.searchActive = true;
            searchField.forceActiveFocus();
            event.accepted = true;
            break;
        case Qt.Key_Question:
            sheet.visible = !sheet.visible;
            event.accepted = true;
            break;
        case Qt.Key_R:
            popup.engine.refreshAll(false);
            event.accepted = true;
            break;
        case Qt.Key_G:
            popup.grouped = !popup.grouped;
            Plasmoid.configuration.groupByRepo = popup.grouped;
            event.accepted = true;
            break;
        case Qt.Key_M:
            if (event.modifiers & Qt.ShiftModifier) {
                popup.beginMarkAllRead();
                event.accepted = true;
            }
            break;
        }
    }
}
