pragma Singleton
import QtQuick

// The applet object the popup reads its configuration from. Defaults match
// package/contents/config/main.xml, so the stub run exercises the same
// out-of-the-box state a new user sees.
QtObject {
    id: plasmoid

    property int status: 1
    property bool busy: false
    property int formFactor: 0
    property int backgroundHints: 1
    property bool configurationRequired: false
    property var contextualActions: []

    function internalAction(name) {
        return dummyAction;
    }

    readonly property QtObject dummyAction: QtObject {
        function trigger() {
        }
    }

    readonly property QtObject configuration: QtObject {
        property string accounts: ""
        property string token: ""
        property string graphqlToken: ""
        property bool useGhCli: false
        property bool participatingOnly: false
        property bool includeRead: false
        property bool actionsEnabled: true
        property bool pullsEnabled: true
        property bool issuesEnabled: true
        property bool profileEnabled: true
        property bool copilotEnabled: false
        property bool statusEnabled: true
        property string defaultTab: "inbox"
        property int inboxIntervalSec: 60
        property int searchIntervalSec: 180
        property int actionsIntervalSec: 300
        property int profileIntervalSec: 1800
        property int statusIntervalSec: 180
        property int watchRepoCount: 6
        property bool includeOrgRepos: false
        property string repoAllowlist: ""
        property string mutedRepos: ""
        property string copilotOrg: ""
        property string accentMode: "system"
        property string customAccent: ""
        property string surfaceMode: "solid"
        property real popupOpacity: 0.85
        property bool notifyEnabled: true
        property bool groupByRepo: false
        property int undoWindowSec: 6
        property bool quietHoursEnabled: false
        property int quietFromHour: 22
        property int quietToHour: 8
    }
}
