// Gitpulse — engine smoke test.
//
//   qml -platform offscreen tests/engine-smoke.qml      (or: make test)
//
// qmllint checks that the QML parses; this checks that Engine.qml actually
// *runs* — bindings evaluate, timers stay off when they should, and the
// unconfigured state is reached without touching the network.
import QtQuick
import "../package/contents/ui/engine" as Core
import "../package/contents/code/GitHub.js" as GH

QtObject {
    id: suite

    property int passed: 0
    property int failed: 0

    function ok(label, condition, detail) {
        if (condition) {
            suite.passed++;
            console.warn("    ✓ " + label);
        } else {
            suite.failed++;
            console.warn("    ✗ " + label + (detail === undefined ? "" : "  — " + detail));
        }
    }

    readonly property var engine: Core.Engine

    Component.onCompleted: {
        // Everything off: this test must not make a single request.
        suite.engine.statusEnabled = false;
        suite.engine.profileEnabled = false;
        suite.engine.copilotEnabled = false;
        suite.engine.actionsEnabled = false;
        suite.engine.pullsEnabled = false;
        suite.engine.issuesEnabled = false;

        console.warn("\n  Engine — unconfigured state");

        ok("instantiates without a token", suite.engine !== null);
        ok("reports NO_TOKEN as the primary error", suite.engine.primaryError === GH.ERR.NO_TOKEN, suite.engine.primaryError);
        ok("badge starts empty", suite.engine.badge.needsYou === 0);
        ok("nothing is tracked yet", suite.engine.badge.tracked === 0);
        ok("has not loaded", !suite.engine.everLoaded);
        ok("is not stale (nothing to be stale about)", !suite.engine.stale);
        ok("has no viewer login", suite.engine.viewerLogin === "");
        ok("all four sections exist and are empty", suite.engine.sections.inbox.length === 0 && suite.engine.sections.actions.length === 0 && suite.engine.sections.pulls.length === 0 && suite.engine.sections.issues.length === 0);

        console.warn("\n  Engine — avatar cache keys");
        suite.engine._avatarCacheVersion = 42;
        suite.engine.viewer = {
            login: "muddyblack",
            avatar_url: "https://avatars.example.test/u/1?v=4"
        };
        ok("keeps GitHub's existing avatar query", suite.engine.avatarSource === "https://avatars.example.test/u/1?v=4&gitpulse-avatar=42", suite.engine.avatarSource);
        ok("shares one cache key for the same actor", suite.engine.avatarSourceFor(suite.engine.viewer.avatar_url) === suite.engine.avatarSource);
        ok("adds a query delimiter when an avatar has none", suite.engine.avatarSourceFor("https://avatars.example.test/u/2") === "https://avatars.example.test/u/2?gitpulse-avatar=42");

        console.warn("\n  Engine — polling is off without a token");
        ok("inbox timer is stopped", !suite.engine._inboxTimer.running);
        ok("search timer is stopped", !suite.engine._searchTimer.running);
        ok("actions timer is stopped", !suite.engine._actionsTimer.running);
        ok("status timer respects statusEnabled", !suite.engine._statusTimer.running);

        console.warn("\n  Engine — actions are safe to call while unconfigured");
        // Each of these used to be a plausible crash: null items, no token, no
        // viewer. They must all be no-ops rather than exceptions.
        var threw = "";
        try {
            suite.engine.markRead(null);
            suite.engine.rerun(null);
            suite.engine.unsubscribe(null);
            suite.engine.refreshProfile();
            suite.engine.refreshCopilot();
            suite.engine.cancel();
            suite.engine.refreshAll(false);
        } catch (e) {
            threw = String(e);
        }
        ok("no-op calls do not throw", threw === "", threw);
        ok("errorFor() on an unknown slot is empty", suite.engine.errorFor("nope") === "");

        console.warn("\n  " + suite.passed + " passed, " + suite.failed + " failed\n");
        Qt.exit(suite.failed > 0 ? 1 : 0);
    }
}
