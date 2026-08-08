// Gitpulse — polling engine and state store.
//
// Deliberately free of any Plasma import: the Quickshell frontend instantiates
// this exact file. Hosts set the input properties, read the output properties
// and call the action methods; nothing in here knows what a plasmoid is.
//
// Singleton (pragma below + engine/qmldir): a host may place several copies of
// the UI in one process — one Gitpulse panel widget per monitor is exactly
// that — and without this each copy ran its own independent poller against
// the same GitHub token, tripling API usage for no benefit. One process, one
// engine, however many views are looking at it.
pragma Singleton
import QtQuick

import "../../code/GitHub.js" as GH
import "../../code/Contract.js" as Contract

QtObject {
    id: engine

    // ── inputs ──────────────────────────────────────────────────────────────
    property string token: ""
    /**
     * Optional second credential, used only for the GraphQL profile query.
     *
     * Fine-grained tokens are excellent for REST and frequently rejected by
     * GraphQL, so rather than force one token to satisfy both, the Profile tab
     * can be given a classic token of its own. Empty means "use `token`".
     */
    property string graphqlToken: ""
    readonly property string profileToken: engine.graphqlToken !== "" ? engine.graphqlToken : engine.token

    property bool active: true // false while the host is hidden/asleep

    property int inboxIntervalSec: 60
    property int searchIntervalSec: 180
    property int actionsIntervalSec: 300
    property int profileIntervalSec: 1800
    property int statusIntervalSec: 180

    property int watchRepoCount: 6
    /** Off by default: one big org otherwise floods Actions with strangers' runs. */
    property bool includeOrgRepos: false
    /** Comma or newline separated "owner/repo" allowlist. Empty = auto. */
    property string repoAllowlist: ""
    /** Repositories the user has muted; filtered out of every section. */
    property string mutedRepos: ""
    property bool participatingOnly: false
    property bool includeRead: false
    /** Organisation to pull Copilot metrics from; empty = personal only. */
    property string copilotOrg: ""

    property bool actionsEnabled: true
    property bool pullsEnabled: true
    property bool issuesEnabled: true
    property bool profileEnabled: true
    property bool copilotEnabled: true
    property bool statusEnabled: true

    // ── outputs ─────────────────────────────────────────────────────────────
    property var sections: ({
            inbox: [],
            actions: [],
            pulls: [],
            issues: []
        })
    property var viewer: null // GET /user
    property var profile: null // Contract.profile()
    property var calendar: null // Contract.calendar()
    property var languages: []
    /** Time-of-day distribution from the public event feed. */
    property var rhythm: []
    property var statusSummary: null
    property var statusComponents: []
    property var copilotComponents: []
    property var incidents: []
    property var copilot: null // billing usage, when reachable
    property var badge: ({
            needsYou: 0,
            unread: 0,
            tracked: 0,
            failing: 0,
            toReview: 0,
            assigned: 0,
            perTab: {
                inbox: 0,
                actions: 0,
                pulls: 0,
                issues: 0
            }
        })

    /** Per-source error codes, so one forbidden endpoint cannot blank the rest. */
    property var errors: ({})
    property bool busy: false
    property bool everLoaded: false
    property double lastUpdateMs: 0
    property double nextPollMs: 0

    property int rateLimit: -1
    property int rateRemaining: -1
    property double rateResetMs: 0

    /**
     * Fatal-for-everything conditions, in the order the banner should report
     * them. A Copilot 403 is not in here: that is a per-tab fact.
     */
    readonly property string primaryError: {
        if (!engine.token)
            return GH.ERR.NO_TOKEN;
        var order = ["inbox", "search", "actions", "profile"];
        for (var i = 0; i < order.length; i++) {
            var e = engine.errors[order[i]];
            if (e === GH.ERR.AUTH || e === GH.ERR.RATE_LIMIT || e === GH.ERR.OFFLINE)
                return e;
        }
        return "";
    }
    readonly property bool stale: engine.everLoaded && engine.primaryError !== ""
    readonly property string viewerLogin: engine.viewer ? engine.viewer.login : ""
    readonly property string avatarUrl: engine.viewer ? engine.viewer.avatar_url : ""
    // All avatar consumers use this versioned source instead of the raw URL.
    // Qt's image cache then serves the same user picture to every tab, while a
    // new cache key every six hours lets changed GitHub avatars appear without
    // keeping an old picture indefinitely.
    property int avatarCacheTtlMs: 6 * 60 * 60 * 1000
    property int _avatarCacheVersion: Math.floor(Date.now() / avatarCacheTtlMs)
    readonly property string avatarSource: engine.avatarSourceFor(engine.avatarUrl)

    /** Emitted with the items that newly became "needs you" since the last poll. */
    signal arrived(var items)
    signal actionFailed(string what, string message)
    /** The engine cannot persist anything; the host owns settings. */
    signal muteRequested(string repo)

    function muteRepo(repo) {
        if (repo)
            engine.muteRequested(repo);
    }

    /**
     * Multi-instance ownership.
     *
     * A shared engine can be watched by several hosts at once (one panel
     * placement per monitor, say). Only one of them should act on `arrived`/
     * `muteRequested` — otherwise the same event fires a desktop notification
     * or a config write once per placement. Whichever host asks first owns
     * it; if that host is destroyed (its placement removed), the next asker
     * takes over.
     */
    property var _owner: null

    function claimOwner(host) {
        if (!engine._owner)
            engine._owner = host;
        return engine._owner === host;
    }

    function releaseOwner(host) {
        if (engine._owner === host)
            engine._owner = null;
    }

    /**
     * Return one shared, expiring source URL for any GitHub avatar.
     *
     * The version is deliberately identical for every use during its TTL: a
     * header, profile and activity entry for the same account therefore hit
     * Qt's one in-memory image entry, not the network independently.
     */
    function avatarSourceFor(url) {
        if (!url)
            return "";
        return url + (url.indexOf("?") === -1 ? "?" : "&") + "gitpulse-avatar=" + engine._avatarCacheVersion;
    }

    property Timer _avatarCacheTimer: Timer {
        interval: engine.avatarCacheTtlMs
        repeat: true
        running: true
        onTriggered: engine._avatarCacheVersion = Math.floor(Date.now() / engine.avatarCacheTtlMs)
    }

    // Ids already reported, so a re-poll does not re-notify.
    property var _announced: ({})
    property var _inflight: []
    property bool _bootstrapped: false

    // ── lifecycle ───────────────────────────────────────────────────────────

    function start() {
        engine._bootstrapped = false;
        GH.clearCache();
        engine.errors = {};
        if (!engine.token) {
            engine.sections = {
                inbox: [],
                actions: [],
                pulls: [],
                issues: []
            };
            engine.viewer = null;
            engine.everLoaded = false;
            // The status tab needs no credentials, and is the one thing worth
            // showing to a user who has not set a token yet.
            engine.refreshStatus();
            return;
        }
        engine.busy = true;
        GH.viewer(engine.token, function (res) {
            engine.busy = false;
            engine._absorb("inbox", res);
            if (!res.ok) {
                engine._touch();
                return;
            }
            engine.viewer = res.data;
            engine._bootstrapped = true;
            engine.refreshAll(true);
        });
    }

    function refreshAll(includeSlow) {
        if (!engine.token) {
            engine.refreshStatus();
            return;
        }
        if (!engine._bootstrapped) {
            engine.start();
            return;
        }
        engine.refreshInbox();
        if (engine.pullsEnabled || engine.issuesEnabled)
            engine.refreshSearch();
        if (engine.actionsEnabled)
            engine.refreshActions();
        if (engine.statusEnabled)
            engine.refreshStatus();
        if (includeSlow) {
            if (engine.profileEnabled)
                engine.refreshProfile();
            if (engine.copilotEnabled)
                engine.refreshCopilot();
        }
    }

    /** Abort every in-flight request — token changed, or the host is closing. */
    function cancel() {
        engine._inflight.forEach(function (x) {
            try {
                if (x)
                    x.abort();
            } catch (e) {}
        });
        engine._inflight = [];
        engine.busy = false;
    }

    // ── sources ─────────────────────────────────────────────────────────────

    function refreshInbox() {
        engine.busy = true;
        engine._track(GH.notifications(engine.token, {
            participating: engine.participatingOnly,
            includeRead: engine.includeRead,
            perPage: 50
        }, function (res) {
            engine.busy = false;
            engine._absorb("inbox", res);
            if (!res.ok || res.notModified) {
                engine._touch();
                return;
            }
            var items = (res.data || []).map(function (raw) {
                return Contract.notification(raw);
            });
            engine._commit("inbox", engine._filterRepos(items));
        }));
    }

    function refreshSearch() {
        var queries = [];
        if (engine.pullsEnabled) {
            queries.push({
                slot: "pulls",
                review: true,
                q: "is:open is:pr archived:false review-requested:@me"
            });
            queries.push({
                slot: "pulls",
                review: false,
                q: "is:open is:pr archived:false author:@me"
            });
        }
        if (engine.issuesEnabled) {
            queries.push({
                slot: "issues",
                review: false,
                q: "is:open is:issue archived:false involves:@me"
            });
        }
        if (!queries.length)
            return;

        engine.busy = true;
        var tasks = queries.map(function (spec) {
            return function (cb) {
                return GH.searchIssues(engine.token, spec.q, cb);
            };
        });

        engine._track(GH.all(tasks, function (results) {
            engine.busy = false;
            var pulls = [];
            var issues = [];
            var byId = {};
            var firstError = null;

            results.forEach(function (res, i) {
                if (!res.ok) {
                    if (!firstError)
                        firstError = res;
                    return;
                }
                var spec = queries[i];
                var list = (res.data && res.data.items) || [];
                list.forEach(function (raw) {
                    var item = Contract.searchItem(raw, engine.viewerLogin);
                    if (spec.review)
                        item.reviewRequested = true;
                    // The same PR can come back from both queries; keep one
                    // record and let reviewRequested stick.
                    var seen = byId[item.id];
                    if (seen) {
                        seen.reviewRequested = seen.reviewRequested || item.reviewRequested;
                        return;
                    }
                    byId[item.id] = item;
                    if (item.kind === Contract.KIND.PULL)
                        pulls.push(item);
                    else
                        issues.push(item);
                });
            });

            engine._absorb("search", firstError || {
                ok: true,
                error: "",
                rate: null
            });
            if (firstError && !pulls.length && !issues.length)
                return; // keep the previous list rather than blanking it

            var next = engine._cloneSections();
            if (engine.pullsEnabled)
                next.pulls = engine._filterRepos(pulls);
            if (engine.issuesEnabled)
                next.issues = engine._filterRepos(issues);
            engine._publish(next);
        }));
    }

    function refreshActions() {
        var manual = engine._allowlist();
        if (manual.length) {
            engine._fetchRuns(manual);
            return;
        }
        engine.busy = true;
        engine._track(GH.recentRepos(engine.token, engine.watchRepoCount, engine.includeOrgRepos, function (res) {
            engine.busy = false;
            engine._absorb("actions", res);
            if (!res.ok)
                return;
            var names = (res.data || []).map(function (r) {
                return r.full_name;
            });
            engine._fetchRuns(names);
        }));
    }

    function _fetchRuns(repoNames) {
        if (!repoNames.length) {
            engine._commit("actions", []);
            return;
        }
        engine.busy = true;
        var tasks = repoNames.map(function (name) {
            return function (cb) {
                return GH.workflowRuns(engine.token, name, 3, cb);
            };
        });
        engine._track(GH.all(tasks, function (results) {
            engine.busy = false;
            var runs = [];
            var firstError = null;
            results.forEach(function (res, i) {
                if (!res.ok) {
                    // A single archived or permission-denied repo must not
                    // take the whole tab down with it.
                    if (!firstError && res.error !== GH.ERR.NOT_FOUND && res.error !== GH.ERR.FORBIDDEN)
                        firstError = res;
                    return;
                }
                var list = (res.data && res.data.workflow_runs) || [];
                list.forEach(function (raw) {
                    raw._repo = repoNames[i];
                    runs.push(Contract.run(raw, engine.viewerLogin));
                });
            });
            engine._absorb("actions", firstError || {
                ok: true,
                error: "",
                rate: null
            });
            engine._commit("actions", runs);
        }));
    }

    function refreshProfile() {
        if (!engine.profileToken)
            return;
        engine._track(GH.profileGraph(engine.profileToken, engine.viewerLogin, function (res) {
            engine._absorb("profile", res);
            if (!res.ok)
                return;
            var user = GH.profileNode(res.data);
            if (!user) {
                engine._setError("profile", GH.ERR.NOT_FOUND, "");
                return;
            }
            engine.profile = Contract.profile(user);
            engine.calendar = Contract.calendar(user.contributionsCollection);
            engine.languages = Contract.languages(user, 6);
        }));

        // One extra REST call, on the slow timer: the contribution calendar has
        // no clock, so the only way to know when in the day someone works is
        // the event feed.
        if (engine.viewerLogin) {
            engine._track(GH.userEvents(engine.token, engine.viewerLogin, function (res) {
                if (res.ok && res.data)
                    engine.rhythm = Contract.rhythm(res.data);
            }));
        }
    }

    function refreshStatus() {
        engine._track(GH.serviceSummary(function (res) {
            engine._absorb("status", res);
            if (!res.ok || !res.data)
                return;
            engine.statusSummary = res.data;
            engine.statusComponents = Contract.components(res.data, true);
            engine.copilotComponents = Contract.copilotComponents(res.data);
        }));
        engine._track(GH.serviceIncidents(function (res) {
            if (res.ok && res.data)
                engine.incidents = res.data.incidents || [];
        }));
    }

    function refreshCopilot() {
        if (!engine.viewerLogin)
            return;
        var now = new Date();
        engine._track(GH.billingUsage(engine.token, engine.viewerLogin, now.getFullYear(), now.getMonth() + 1, function (res) {
            engine._absorb("copilot", res);
            if (!res.ok) {
                engine.copilot = null;
                return;
            }
            engine.copilot = engine._summariseUsage(res.data);
        }));
        if (engine.copilotOrg) {
            engine._track(GH.copilotOrgMetrics(engine.token, engine.copilotOrg, function (res) {
                if (!res.ok || !res.data || !res.data.length)
                    return;
                var latest = res.data[res.data.length - 1];
                var c = engine.copilot || {};
                c.org = engine.copilotOrg;
                c.orgActive = latest.total_active_users || 0;
                c.orgEngaged = latest.total_engaged_users || 0;
                c.orgDate = latest.date || "";
                engine.copilot = c;
            }));
        }
    }

    /**
     * The billing usage report is a flat list of line items. Only the Copilot
     * ones are interesting here, and they are identified by product, not by a
     * stable id, so match loosely and total what we find.
     */
    function _summariseUsage(payload) {
        var items = (payload && payload.usageItems) || [];
        var copilotItems = items.filter(function (u) {
            return String(u.product || "").toLowerCase().indexOf("copilot") >= 0;
        });
        if (!copilotItems.length)
            return null;
        var quantity = 0;
        var gross = 0;
        var net = 0;
        var discount = 0;
        var perSku = {};
        copilotItems.forEach(function (u) {
            quantity += u.quantity || 0;
            gross += u.grossAmount || 0;
            net += u.netAmount || 0;
            discount += u.discountAmount || 0;
            var sku = u.sku || u.product || "usage";
            perSku[sku] = (perSku[sku] || 0) + (u.quantity || 0);
        });
        return {
            quantity: quantity,
            grossAmount: gross,
            netAmount: net,
            discountAmount: discount,
            included: discount,
            perSku: perSku,
            skus: Object.keys(perSku).map(function (k) {
                return {
                    name: k,
                    quantity: perSku[k]
                };
            }).sort(function (a, b) {
                return b.quantity - a.quantity;
            })
        };
    }

    // ── mutations ───────────────────────────────────────────────────────────

    function markRead(item) {
        if (!item || item.kind !== Contract.KIND.NOTIFICATION || !item.unread)
            return;
        engine._setUnread(item.id, false);
        GH.markThreadRead(engine.token, item.threadId, function (res) {
            if (!res.ok) {
                engine._setUnread(item.id, true); // put it back, honestly
                engine.actionFailed("mark-read", res.message || res.error);
            }
        });
    }

    function markUnreadLocally(item) {
        // GitHub has no "mark unread" endpoint, so this is a local-only undo
        // of an optimistic update that has not been sent yet.
        engine._setUnread(item.id, true);
    }

    /**
     * Marks everything read.
     *
     * The caller is expected to defer this behind an undo window: the API call
     * cannot be reversed, so the only real undo is one that never fires.
     */
    function markAllRead(cb) {
        var stamp = new Date().toISOString();
        GH.markAllRead(engine.token, stamp, function (res) {
            if (!res.ok)
                engine.actionFailed("mark-all-read", res.message || res.error);
            else
                engine.refreshInbox();
            if (cb)
                cb(res.ok);
        });
    }

    function unsubscribe(item) {
        if (!item || !item.threadId)
            return;
        GH.unsubscribeThread(engine.token, item.threadId, function (res) {
            if (!res.ok)
                engine.actionFailed("unsubscribe", res.message || res.error);
            else
                engine.markRead(item);
        });
    }

    function rerun(item) {
        if (!item || item.kind !== Contract.KIND.RUN)
            return;
        GH.rerunWorkflow(engine.token, item.repo, item.runId, function (res) {
            if (!res.ok)
                engine.actionFailed("rerun", res.message || res.error);
            else
                engine.refreshActions();
        });
    }

    function _setUnread(id, unread) {
        var next = engine._cloneSections();
        next.inbox = next.inbox.map(function (i) {
            if (i.id !== id)
                return i;
            var copy = {};
            for (var k in i)
                copy[k] = i[k];
            copy.unread = unread;
            copy.tone = unread ? Contract.reasonTone(copy.reason) : "muted";
            return copy;
        });
        engine._publish(next);
    }

    // ── plumbing ────────────────────────────────────────────────────────────

    function _track(handle) {
        if (handle)
            engine._inflight.push(handle);
        // Keep the list from growing without bound over a long session.
        if (engine._inflight.length > 32)
            engine._inflight = engine._inflight.slice(-16);
    }

    function _cloneSections() {
        return {
            inbox: engine.sections.inbox || [],
            actions: engine.sections.actions || [],
            pulls: engine.sections.pulls || [],
            issues: engine.sections.issues || []
        };
    }

    function _commit(slot, items) {
        var next = engine._cloneSections();
        next[slot] = items;
        engine._publish(next);
    }

    function _publish(next) {
        engine.badge = Contract.badge(next); // also runs cross-tab dedupe
        engine.sections = next;
        engine.everLoaded = true;
        engine._touch();
        engine._announce(next);
    }

    function _touch() {
        engine.lastUpdateMs = Date.now();
        engine.nextPollMs = engine.lastUpdateMs + engine.inboxIntervalSec * 1000;
    }

    /** Fire `arrived` for needs-you items this session has not reported yet. */
    function _announce(next) {
        var fresh = [];
        ["inbox", "actions", "pulls"].forEach(function (slot) {
            (next[slot] || []).forEach(function (item) {
                if (!item.counts)
                    return;
                if (engine._announced[item.id])
                    return;
                engine._announced[item.id] = true;
                fresh.push(item);
            });
        });
        // The first load is the user's existing backlog, not news.
        if (fresh.length && engine.everLoaded && Object.keys(engine._announced).length > fresh.length)
            engine.arrived(fresh);
    }

    function _absorb(slot, res) {
        if (res.rate && res.rate.limit > 0) {
            engine.rateLimit = res.rate.limit;
            engine.rateRemaining = res.rate.remaining;
            engine.rateResetMs = res.rate.reset > 0 ? res.rate.reset * 1000 : 0;
        }
        engine._setError(slot, res.ok ? "" : res.error, res.message || "");
    }

    function _setError(slot, code, message) {
        var next = {};
        for (var k in engine.errors)
            next[k] = engine.errors[k];
        if (code)
            next[slot] = code;
        else
            delete next[slot];
        next[slot + ":msg"] = message || "";
        engine.errors = next;
    }

    function errorFor(slot) {
        return engine.errors[slot] || "";
    }

    function messageFor(slot) {
        return engine.errors[slot + ":msg"] || "";
    }

    function _allowlist() {
        return String(engine.repoAllowlist || "").split(/[\s,]+/).map(function (s) {
            return s.trim();
        }).filter(function (s) {
            return s.indexOf("/") > 0;
        });
    }

    function _muted() {
        var set = {};
        String(engine.mutedRepos || "").split(/[\s,]+/).forEach(function (r) {
            var t = r.trim().toLowerCase();
            if (t.indexOf("/") > 0)
                set[t] = true;
        });
        return set;
    }

    /** Applies the allowlist and the mute list to already-normalised items. */
    function _filterRepos(items) {
        var allow = engine._allowlist();
        var muted = engine._muted();
        var set = {};
        allow.forEach(function (r) {
            set[r.toLowerCase()] = true;
        });
        return items.filter(function (i) {
            var name = String(i.repo).toLowerCase();
            if (muted[name])
                return false;
            return allow.length ? !!set[name] : true;
        });
    }

    // ── timers ──────────────────────────────────────────────────────────────
    //
    // One per source: the inbox is cheap and wants to be current, the search
    // API is expensive and does not, and the profile changes once a day.

    readonly property Timer _inboxTimer: Timer {
        interval: Math.max(30, engine.inboxIntervalSec) * 1000
        repeat: true
        running: engine.active && engine.token !== "" && engine.primaryError !== GH.ERR.RATE_LIMIT
        onTriggered: engine.refreshInbox()
    }

    readonly property Timer _searchTimer: Timer {
        interval: Math.max(60, engine.searchIntervalSec) * 1000
        repeat: true
        running: engine._inboxTimer.running && (engine.pullsEnabled || engine.issuesEnabled)
        onTriggered: engine.refreshSearch()
    }

    readonly property Timer _actionsTimer: Timer {
        interval: Math.max(60, engine.actionsIntervalSec) * 1000
        repeat: true
        running: engine._inboxTimer.running && engine.actionsEnabled
        onTriggered: engine.refreshActions()
    }

    readonly property Timer _slowTimer: Timer {
        interval: Math.max(300, engine.profileIntervalSec) * 1000
        repeat: true
        running: engine._inboxTimer.running && (engine.profileEnabled || engine.copilotEnabled)
        onTriggered: {
            if (engine.profileEnabled)
                engine.refreshProfile();
            if (engine.copilotEnabled)
                engine.refreshCopilot();
        }
    }

    readonly property Timer _statusTimer: Timer {
        interval: Math.max(60, engine.statusIntervalSec) * 1000
        repeat: true
        running: engine.active && engine.statusEnabled
        onTriggered: engine.refreshStatus()
    }

    /**
     * Rate-limit recovery. Polling stops while the budget is exhausted; this
     * wakes it up a few seconds after GitHub says the window rolls over.
     */
    readonly property Timer _resumeTimer: Timer {
        interval: Math.max(5000, engine.rateResetMs - Date.now() + 5000)
        repeat: false
        running: engine.primaryError === GH.ERR.RATE_LIMIT && engine.rateResetMs > 0
        onTriggered: {
            engine._setError("inbox", "", "");
            engine._setError("search", "", "");
            engine._setError("actions", "", "");
            engine.refreshAll(false);
        }
    }

    onTokenChanged: {
        engine.cancel();
        engine._announced = {};
        engine.start();
    }
}
