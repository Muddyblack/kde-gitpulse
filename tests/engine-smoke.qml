// Gitpulse — engine smoke test.
//
//   qml -platform offscreen tests/engine-smoke.qml      (or: make test)
//
// qmllint checks that the QML parses; this checks that Engine.qml actually
// *runs* — bindings evaluate, timers stay off when they should, and the
// unconfigured state is reached without touching the network.
import QtQuick
import "../package/contents/ui/engine" as Core
import "../package/contents/code/Http.js" as Http

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
        ok("reports NO_TOKEN as the primary error", suite.engine.primaryError === Http.ERR.NO_TOKEN, suite.engine.primaryError);
        ok("badge starts empty", suite.engine.badge.needsYou === 0);
        ok("nothing is tracked yet", suite.engine.badge.tracked === 0);
        ok("has not loaded", !suite.engine.everLoaded);
        ok("is not stale (nothing to be stale about)", !suite.engine.stale);
        ok("has no viewer login", suite.engine.viewerLogin === "");
        ok("all four sections exist and are empty", suite.engine.sections.inbox.length === 0 && suite.engine.sections.actions.length === 0 && suite.engine.sections.pulls.length === 0 && suite.engine.sections.issues.length === 0);

        console.warn("\n  Engine — avatar cache keys");
        suite.engine._avatarCacheVersion = 42;
        ok("keeps an existing avatar query", suite.engine.avatarSourceFor("https://avatars.example.test/u/1?v=4") === "https://avatars.example.test/u/1?v=4&gitpulse-avatar=42");
        ok("shares one cache key for the same actor", suite.engine.avatarSourceFor("https://avatars.example.test/u/1?v=4") === suite.engine.avatarSourceFor("https://avatars.example.test/u/1?v=4"));
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
        ok("an empty account list is not configured", !suite.engine.configured);
        ok("and yields no accounts to poll", suite.engine.accounts.length === 0);
        ok("markAllRead with no accounts calls back false", (function () {
                var seen = null;
                suite.engine.markAllRead(function (okd) {
                    seen = okd;
                });
                return seen === false;
            })());

        console.warn("\n  Engine — quiet hours");
        // The badge keeps counting during quiet hours; only the notification
        // is withheld, so nothing is hidden — it just does not interrupt.
        suite.engine.quietFromHour = 0;
        suite.engine.quietToHour = 0;
        ok("equal bounds disable the window", !suite.engine.quiet);
        suite.engine._nowHour = 23;
        suite.engine.quietFromHour = 22;
        suite.engine.quietToHour = 8;
        ok("a window that wraps midnight includes 23:00", suite.engine.quiet);
        suite.engine._nowHour = 12;
        ok("and excludes midday", !suite.engine.quiet);
        suite.engine._nowHour = 3;
        ok("and includes the small hours", suite.engine.quiet);
        suite.engine.quietFromHour = 9;
        suite.engine.quietToHour = 17;
        suite.engine._nowHour = 12;
        ok("a same-day window includes its middle", suite.engine.quiet);
        suite.engine._nowHour = 20;
        ok("and excludes the evening", !suite.engine.quiet);
        suite.engine.quietFromHour = 0;
        suite.engine.quietToHour = 0;

        console.warn("\n  Engine — busy is a count, not a flag");
        ok("nothing in flight means not busy", !suite.engine.busy);
        suite.engine._pending = 2;
        ok("two sources in flight is busy", suite.engine.busy);
        suite.engine._pending = 1;
        ok("one finishing does not clear the spinner", suite.engine.busy);
        suite.engine._pending = 0;
        ok("the last one does", !suite.engine.busy);

        console.warn("\n  " + suite.passed + " passed, " + suite.failed + " failed\n");
        Qt.exit(suite.failed > 0 ? 1 : 0);
    }
}
