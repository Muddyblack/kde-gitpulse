// Borrows the GitHub CLI's credential instead of asking for a token.
//
// Strictly opt-in: the widget still has no dependency on `gh`, it just uses it
// when it is there and the user prefers it. `gh auth token` prints the token
// the CLI already stores, so nothing new is created and nothing is written.
//
// Note the CLI's default scopes (repo, read:org, gist, workflow) do not include
// read:user, so the contribution graph may still need its own classic token.
// Run `gh auth refresh -s read:user` to add it.
import QtQuick
import Quickshell.Io

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
        // StdioCollector.text is read-only and reset by the collector itself on
        // each run, so there is nothing to clear here.
        proc.running = true;
    }

    onEnabledChanged: gh.refresh()

    readonly property Process proc: Process {
        // Through a shell, for two reasons: `command -v` tells "gh is missing"
        // apart from "gh is not logged in" (different advice), and PATH is
        // resolved the same way the user's own terminal would.
        command: ["sh", "-c", "command -v gh >/dev/null 2>&1 || { echo __GITPULSE_NO_GH__; exit 0; }; gh auth token 2>/dev/null"]
        running: false

        // streamFinished, not the process's running change: stdout is delivered
        // asynchronously and can still be empty at the moment the process is
        // reaped, which made a perfectly good login look unauthenticated.
        stdout: StdioCollector {
            id: collector

            onStreamFinished: {
                var out = String(collector.text || "").trim();
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
    }

    /** Re-ask periodically: gh tokens rotate, and the user may log in later. */
    readonly property Timer _refresh: Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: gh.enabled
        onTriggered: gh.refresh()
    }
}
