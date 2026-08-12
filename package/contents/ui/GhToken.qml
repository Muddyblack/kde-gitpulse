// Borrows the GitHub CLI's credential instead of asking for a token.
//
// Strictly opt-in: the widget still has no dependency on `gh`, it just uses it
// when it is there and the user prefers it. `gh auth token` prints the token
// the CLI already stores, so nothing new is created and nothing is written.
//
// The CLI's default scopes (repo, read:org, gist, workflow) do not include
// read:user, so the contribution graph may still want its own classic token —
// or `gh auth refresh -s read:user`.
import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

QtObject {
    id: gh

    property bool enabled: false
    property string token: ""
    /** "", "probing", "ok", "missing", "unauthenticated" */
    property string state: ""

    function refresh() {
        if (!gh.enabled) {
            gh.token = "";
            gh.state = "";
            return;
        }
        gh.state = "probing";
        source.connectSource(gh.command);
    }

    onEnabledChanged: gh.refresh()
    // `enabled` can already be true when this object is created — e.g. config
    // set declaratively (NixOS/home-manager) rather than toggled in the UI —
    // in which case onEnabledChanged never sees a false→true transition to
    // react to.
    Component.onCompleted: gh.refresh()

    // `command -v` first so a missing binary is distinguishable from a missing
    // login — they need different advice.
    readonly property string command: "sh -c 'command -v gh >/dev/null 2>&1 || { echo __GITPULSE_NO_GH__; exit 0; }; gh auth token 2>/dev/null'"

    readonly property Plasma5Support.DataSource source: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []

        onNewData: function (src, data) {
            disconnectSource(src);
            var out = String(data["stdout"] || "").trim();
            if (out === "__GITPULSE_NO_GH__") {
                gh.token = "";
                gh.state = "missing";
            } else if (out.length > 0) {
                gh.token = out;
                gh.state = "ok";
            } else {
                gh.token = "";
                gh.state = "unauthenticated";
            }
        }
    }

    /** Re-ask periodically: gh tokens rotate, and the user may log in later. */
    readonly property Timer _refresh: Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: gh.enabled
        onTriggered: gh.refresh()
    }
}
