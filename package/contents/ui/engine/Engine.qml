// Gitpulse — polling engine and state store.
//
// Deliberately free of any Plasma import: the Quickshell frontend instantiates
// this exact file. Hosts set the input properties, read the output properties
// and call the action methods; nothing in here knows what a plasmoid is, and
// nothing in here knows what a forge is either — Forge.js dispatches to
// GitHub, GitLab or Forgejo per account.
//
// Singleton (pragma below + engine/qmldir): a host may place several copies of
// the UI in one process — one Gitpulse panel widget per monitor is exactly
// that — and without this each copy ran its own independent poller against
// the same tokens, tripling API usage for no benefit. One process, one
// engine, however many views are looking at it.
pragma Singleton
import QtQuick

import "../../code/Http.js" as Http
import "../../code/Forge.js" as Forge
import "../../code/GitHub.js" as GitHub
import "../../code/Contract.js" as Contract

QtObject {
    id: engine

    // ── inputs ──────────────────────────────────────────────────────────────
    /**
     * The configured accounts, as the JSON string the host persists.
     *
     * A string rather than a list because both hosts store settings in flat
     * key/value files (Plasma's kcfg, Quickshell's JsonAdapter), and a string
     * survives both without either of them learning the account schema.
     */
    property string accountsJson: ""
    /** Whatever `gh auth token` produced; accounts with useCli borrow it. */
    property string cliToken: ""

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

    /**
     * Quiet hours, as 0–23 local hours. While inside the window the badge and
     * the lists keep updating and `arrived` simply does not fire — the widget
     * stays honest without interrupting anyone. Equal values disable it.
     */
    property int quietFromHour: 0
    property int quietToHour: 0

    /** Which account the Profile tab is showing; empty means the first one. */
    property string profileAccountId: ""

    // ── accounts ────────────────────────────────────────────────────────────
    readonly property var accounts: Forge.active(Forge.parse(engine.accountsJson), engine.cliToken)
    readonly property bool configured: engine.accounts.length > 0
    /** Identity per account id, filled in by the bootstrap call. */
    property var identities: ({})

    /** Accounts with their resolved login and id merged back in. */
    readonly property var liveAccounts: engine.accounts.map(function (a) {
        var who = engine.identities[a.id];
        if (!who)
            return a;
        var copy = {};
        for (var k in a)
            copy[k] = a[k];
        copy.login = who.login;
        copy.userId = who.id;
        copy.avatarUrl = who.avatarUrl;
        return copy;
    })

    function accountFor(id) {
        var list = engine.liveAccounts;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    // ── outputs ─────────────────────────────────────────────────────────────
    property var sections: ({
            inbox: [],
            actions: [],
            pulls: [],
            issues: []
        })
    /** The first account's identity — what the tray avatar and header use. */
    readonly property var viewer: engine.liveAccounts.length && engine.identities[engine.liveAccounts[0].id] ? engine.identities[engine.liveAccounts[0].id] : null

    /** Per-account { profile, calendar, languages, clock }. */
    property var profiles: ({})

    readonly property string activeProfileId: {
        var list = engine.liveAccounts;
        if (!list.length)
            return "";
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === engine.profileAccountId)
                return list[i].id;
        }
        return list[0].id;
    }
    readonly property var activeProfileAccount: engine.accountFor(engine.activeProfileId)
    readonly property var _profileBundle: engine.profiles[engine.activeProfileId] || null

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

    // The Profile tab reads these four; which account they describe is
    // `activeProfileId`, and the tab offers a picker when there is more than
    // one.
    readonly property var profile: engine._profileBundle ? engine._profileBundle.profile : null
    readonly property var calendar: engine._profileBundle ? engine._profileBundle.calendar : null
    readonly property var languages: engine._profileBundle ? engine._profileBundle.languages : []
    /** Contract.clock() output: 24 hourly buckets in local time. */
    readonly property var clock: engine._profileBundle ? engine._profileBundle.clock : null
    readonly property var rhythm: Contract.rhythm(engine.clock)

    /** Per-source error codes, so one forbidden endpoint cannot blank the rest. */
    property var errors: ({})
    /** Per-account error codes, so a banner can name the account that broke. */
    property var accountErrors: ({})

    /**
     * Busy is a counter, not a flag.
     *
     * Five sources finish at five different times, and a plain boolean meant
     * whichever finished first switched the spinner off while the other four
     * were still running — a spinner that flickers on every poll.
     */
    property int _pending: 0
    readonly property bool busy: engine._pending > 0
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
        if (!engine.configured)
            return Http.ERR.NO_TOKEN;
        var order = ["inbox", "search", "actions", "profile"];
        for (var i = 0; i < order.length; i++) {
            var e = engine.errors[order[i]];
            if (e === Http.ERR.AUTH || e === Http.ERR.RATE_LIMIT || e === Http.ERR.OFFLINE)
                return e;
        }
        return "";
    }
    readonly property bool stale: engine.everLoaded && engine.primaryError !== ""
    readonly property string viewerLogin: engine.viewer ? engine.viewer.login : ""
    readonly property string avatarUrl: engine.viewer ? engine.viewer.avatarUrl : ""
    // All avatar consumers use this versioned source instead of the raw URL.
    // Qt's image cache then serves the same user picture to every tab, while a
    // new cache key every six hours lets changed avatars appear without
    // keeping an old picture indefinitely.
    property int avatarCacheTtlMs: 6 * 60 * 60 * 1000
    property int _avatarCacheVersion: Math.floor(Date.now() / avatarCacheTtlMs)
    readonly property string avatarSource: engine.avatarSourceFor(engine.avatarUrl)

    /** True while the local clock is inside the configured quiet window. */
    readonly property bool quiet: {
        if (engine.quietFromHour === engine.quietToHour)
            return false;
        var h = engine._nowHour;
        return engine.quietFromHour < engine.quietToHour ? h >= engine.quietFromHour && h < engine.quietToHour : h >= engine.quietFromHour || h < engine.quietToHour;
    }
    property int _nowHour: new Date().getHours()

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
     * Return one shared, expiring source URL for any avatar.
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

    /** Re-evaluates `quiet` without a binding on Date.now(), which never changes. */
    property Timer _clockTimer: Timer {
        interval: 60000
        repeat: true
        running: engine.quietFromHour !== engine.quietToHour
        onTriggered: engine._nowHour = new Date().getHours()
    }

    // Ids already reported, so a re-poll does not re-notify.
    property var _announced: ({})
    property var _inflight: []
    /**
     * True once every enabled source has reported at least once.
     *
     * Without it the first load notified: the inbox committed, then Actions
     * committed a moment later, and those Actions items looked "new" because
     * they were not in the set the inbox had just seeded. Everything present
     * on the first pass is backlog, not news.
     */
    property bool _seeded: false
    property var _seenSources: ({})
    property int _bootstrapped: 0

    // ── lifecycle ───────────────────────────────────────────────────────────

    function start() {
        engine.cancel();
        engine._bootstrapped = 0;
        engine._seeded = false;
        engine._seenSources = {};
        Http.clearCache();
        engine.errors = {};
        engine.accountErrors = {};

        var list = engine.accounts;
        if (!list.length) {
            engine.sections = {
                inbox: [],
                actions: [],
                pulls: [],
                issues: []
            };
            engine.identities = {};
            engine.profiles = {};
            engine.everLoaded = false;
            // The status tab needs no credentials, and is the one thing worth
            // showing to a user who has not set an account up yet.
            engine.refreshStatus();
            return;
        }

        // Identity first, and for every account at once: the login is what
        // decides "yours" on a pipeline and what the search filters key on, so
        // nothing else may run before it lands.
        var left = list.length;
        engine._pending += 1;
        list.forEach(function (acct) {
            engine._track(Forge.viewer(acct, function (res) {
                if (res.ok && res.data) {
                    var next = {};
                    for (var k in engine.identities)
                        next[k] = engine.identities[k];
                    next[acct.id] = res.data;
                    engine.identities = next;
                } else {
                    engine._absorbAccount(acct, "inbox", res);
                }
                if (--left > 0)
                    return;
                engine._pending -= 1;
                engine._bootstrapped = Object.keys(engine.identities).length;
                if (engine._bootstrapped > 0)
                    engine.refreshAll(true);
                else
                    engine._touch();
            }));
        });
    }

    function refreshAll(includeSlow) {
        if (!engine.configured) {
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

    /** Abort every in-flight request — an account changed, or the host is closing. */
    function cancel() {
        engine._inflight.forEach(function (x) {
            try {
                if (x)
                    x.abort();
            } catch (e) {}
        });
        engine._inflight = [];
        engine._pending = 0;
    }

    // ── sources ─────────────────────────────────────────────────────────────
    //
    // Every source is the same shape: fan out over the accounts that support
    // it, merge what came back, and record the worst error. `_fanOut` is that
    // shape, written once.

    /**
     * Run `call(account, done)` for every account supporting `source` and
     * hand the merged results to `finish(perAccount)`.
     */
    function _fanOut(slot, source, call, finish) {
        var list = engine.liveAccounts.filter(function (a) {
            return Forge.capabilities(a)[source];
        });
        if (!list.length) {
            finish([], []);
            return;
        }
        engine._pending += 1;
        var results = new Array(list.length);
        var left = list.length;
        list.forEach(function (acct, i) {
            engine._track(call(acct, function (res) {
                results[i] = res;
                engine._absorbAccount(acct, slot, res);
                if (--left > 0)
                    return;
                engine._pending -= 1;
                engine._absorbSlot(slot, list, results);
                finish(results, list);
            }));
        });
    }

    function refreshInbox() {
        engine._fanOut("inbox", "inbox", function (acct, done) {
            return Forge.inbox(acct, {
                participating: engine.participatingOnly,
                includeRead: engine.includeRead,
                perPage: 50
            }, done);
        }, function (results) {
            var items = [];
            var changed = false;
            results.forEach(function (res) {
                if (!res.ok || !res.data)
                    return;
                if (!res.notModified)
                    changed = true;
                items = items.concat(res.data);
            });
            engine._sourceSeen("inbox");
            if (!results.length || (!changed && engine.everLoaded)) {
                engine._touch();
                return;
            }
            engine._commit("inbox", engine._filterRepos(items));
        });
    }

    function refreshSearch() {
        if (!engine.pullsEnabled && !engine.issuesEnabled) {
            engine._sourceSeen("search");
            return;
        }
        engine._fanOut("search", "pulls", function (acct, done) {
            return Forge.work(acct, {
                pulls: engine.pullsEnabled,
                issues: engine.issuesEnabled
            }, done);
        }, function (results) {
            var pulls = [];
            var issues = [];
            var any = false;
            results.forEach(function (res) {
                if (!res.ok || !res.data)
                    return;
                any = true;
                pulls = pulls.concat(res.data.pulls || []);
                issues = issues.concat(res.data.issues || []);
            });
            engine._sourceSeen("search");
            if (!any)
                return; // keep the previous list rather than blanking it

            var next = engine._cloneSections();
            if (engine.pullsEnabled)
                next.pulls = engine._filterRepos(pulls);
            if (engine.issuesEnabled)
                next.issues = engine._filterRepos(issues);
            engine._publish(next);
        });
    }

    function refreshActions() {
        var manual = engine._allowlist();
        engine._fanOut("actions", "pipelines", function (acct, done) {
            return Forge.pipelines(acct, {
                repos: manual,
                count: engine.watchRepoCount,
                includeOrgs: engine.includeOrgRepos
            }, done);
        }, function (results) {
            var runs = [];
            var any = false;
            results.forEach(function (res) {
                if (!res.ok || !res.data)
                    return;
                any = true;
                runs = runs.concat(res.data);
            });
            engine._sourceSeen("actions");
            if (!any && engine.everLoaded)
                return;
            engine._commit("actions", engine._filterRepos(runs));
        });
    }

    /**
     * Profile, contribution calendar, languages and the hour dial.
     *
     * Runs for every account that can serve them, not only the visible one:
     * switching the Profile tab's account picker should be instant, not a
     * fresh round trip.
     */
    function refreshProfile() {
        engine._fanOut("profile", "profile", function (acct, done) {
            return Forge.profile(acct, done);
        }, function (results, list) {
            results.forEach(function (res, i) {
                if (!res.ok || !res.data)
                    return;
                var acct = list[i];
                engine._mergeProfile(acct.id, {
                    profile: res.data.profile,
                    calendar: res.data.calendar,
                    languages: res.data.languages
                });

                var hint = {
                    repos: res.data.repos || [],
                    viewerId: res.data.viewerId
                };
                engine._track(Forge.activity(acct, hint, function (act) {
                    if (act.ok && act.data)
                        engine._mergeProfile(acct.id, {
                            clock: act.data.clock,
                            // Only GitHub answers the calendar in the profile
                            // call; the others answer it here.
                            calendar: act.data.calendar || undefined
                        });
                }));

                if (!(res.data.languages || []).length)
                    engine._track(Forge.languages(acct, hint, function (langs) {
                        if (langs.ok && langs.data && langs.data.length)
                            engine._mergeProfile(acct.id, {
                                languages: langs.data
                            });
                    }));
            });
        });
    }

    /** Patch one account's profile bundle without discarding the other keys. */
    function _mergeProfile(id, patch) {
        var next = {};
        for (var k in engine.profiles)
            next[k] = engine.profiles[k];
        var bundle = {};
        var prev = engine.profiles[id] || {};
        for (var p in prev)
            bundle[p] = prev[p];
        for (var q in patch) {
            if (patch[q] !== undefined)
                bundle[q] = patch[q];
        }
        next[id] = bundle;
        engine.profiles = next;
    }

    function refreshStatus() {
        engine._track(GitHub.serviceSummary(function (res) {
            engine._setError("status", res.ok ? "" : res.error, res.message || "");
            if (!res.ok || !res.data)
                return;
            engine.statusSummary = res.data;
            engine.statusComponents = Contract.components(res.data, true);
            engine.copilotComponents = Contract.copilotComponents(res.data);
        }));
        engine._track(GitHub.serviceIncidents(function (res) {
            if (res.ok && res.data)
                engine.incidents = res.data.incidents || [];
        }));
    }

    /** Copilot is a GitHub concept; other forges simply do not offer the tab. */
    readonly property var _copilotAccount: {
        var list = engine.liveAccounts;
        for (var i = 0; i < list.length; i++) {
            if (Forge.capabilities(list[i]).copilot && list[i].login)
                return list[i];
        }
        return null;
    }

    function refreshCopilot() {
        var acct = engine._copilotAccount;
        if (!acct)
            return;
        var now = new Date();
        engine._track(GitHub.billingUsage(acct, now.getFullYear(), now.getMonth() + 1, function (res) {
            engine._setError("copilot", res.ok ? "" : res.error, res.message || "");
            if (!res.ok) {
                engine.copilot = null;
                return;
            }
            engine.copilot = engine._summariseUsage(res.data);
        }));
        if (engine.copilotOrg) {
            engine._track(GitHub.copilotOrgMetrics(acct, engine.copilotOrg, function (res) {
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
        var acct = engine.accountFor(item.account);
        if (!acct)
            return;
        engine._setUnread(item.id, false);
        Forge.markRead(acct, item, function (res) {
            if (!res.ok) {
                engine._setUnread(item.id, true); // put it back, honestly
                engine.actionFailed("mark-read", res.message || res.error);
            }
        });
    }

    function markUnreadLocally(item) {
        // No forge has a "mark unread" endpoint, so this is a local-only undo
        // of an optimistic update that has not been sent yet.
        engine._setUnread(item.id, true);
    }

    /**
     * Marks everything read, on every account.
     *
     * The caller is expected to defer this behind an undo window: the API call
     * cannot be reversed, so the only real undo is one that never fires.
     */
    function markAllRead(cb) {
        var stamp = new Date().toISOString();
        var list = engine.liveAccounts.filter(function (a) {
            return Forge.capabilities(a).markAllRead;
        });
        if (!list.length) {
            if (cb)
                cb(false);
            return;
        }
        var left = list.length;
        var allOk = true;
        list.forEach(function (acct) {
            Forge.markAllRead(acct, stamp, function (res) {
                if (!res.ok) {
                    allOk = false;
                    engine.actionFailed("mark-all-read", res.message || res.error);
                }
                if (--left > 0)
                    return;
                if (allOk)
                    engine.refreshInbox();
                if (cb)
                    cb(allOk);
            });
        });
    }

    function unsubscribe(item) {
        var acct = item ? engine.accountFor(item.account) : null;
        if (!acct || !item.threadId || !Forge.capabilities(acct).unsubscribe)
            return;
        Forge.unsubscribe(acct, item, function (res) {
            if (!res.ok)
                engine.actionFailed("unsubscribe", res.message || res.error);
            else
                engine.markRead(item);
        });
    }

    function rerun(item) {
        var acct = item ? engine.accountFor(item.account) : null;
        if (!acct || item.kind !== Contract.KIND.RUN || !Forge.capabilities(acct).rerun)
            return;
        Forge.rerun(acct, item, function (res) {
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
        if (!handle)
            return;
        // Drop the handles that already finished before adding another, so a
        // long session holds only what is genuinely in flight.
        engine._inflight = engine._inflight.filter(function (x) {
            return x && x.readyState !== undefined && x.readyState !== 4;
        });
        engine._inflight.push(handle);
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

    /** The set of sources that must have reported before news counts as news. */
    readonly property var _expectedSources: {
        var want = ["inbox"];
        if (engine.pullsEnabled || engine.issuesEnabled)
            want.push("search");
        if (engine.actionsEnabled)
            want.push("actions");
        return want;
    }

    function _sourceSeen(name) {
        if (engine._seeded || engine._seenSources[name])
            return;
        var next = {};
        for (var k in engine._seenSources)
            next[k] = engine._seenSources[k];
        next[name] = true;
        engine._seenSources = next;
        engine._seeded = engine._expectedSources.every(function (s) {
            return next[s];
        });
    }

    /**
     * Fire `arrived` for needs-you items this session has not reported yet.
     *
     * The announced set is rebuilt from the live items on every publish rather
     * than appended to, which both bounds it — it used to grow for the life of
     * the session — and lets an item that genuinely comes back announce again.
     */
    function _announce(next) {
        var fresh = [];
        var live = {};
        ["inbox", "actions", "pulls"].forEach(function (slot) {
            (next[slot] || []).forEach(function (item) {
                if (!item.counts)
                    return;
                live[item.id] = true;
                if (!engine._announced[item.id])
                    fresh.push(item);
            });
        });
        engine._announced = live;
        // The first full pass is the user's existing backlog, not news.
        if (fresh.length && engine._seeded && !engine.quiet)
            engine.arrived(fresh);
    }

    /** Rate headers and the per-account error note. */
    function _absorbAccount(acct, slot, res) {
        if (res.rate && res.rate.limit > 0) {
            engine.rateLimit = res.rate.limit;
            engine.rateRemaining = res.rate.remaining;
            engine.rateResetMs = res.rate.reset > 0 ? res.rate.reset * 1000 : 0;
        }
        var next = {};
        for (var k in engine.accountErrors)
            next[k] = engine.accountErrors[k];
        if (res.ok || !res.error)
            delete next[acct.id];
        else
            next[acct.id] = {
                error: res.error,
                message: res.message || "",
                slot: slot
            };
        engine.accountErrors = next;
    }

    /**
     * One error per source, across every account.
     *
     * A slot only reports failure when nothing came back at all: with two
     * accounts configured, one expired token must not blank a tab the other
     * account is still filling — it shows up as an account error instead, and
     * the banner names it.
     */
    function _absorbSlot(slot, accts, results) {
        var worst = "";
        var message = "";
        var anyOk = false;
        var rank = {
            auth: 4,
            rate_limit: 3,
            offline: 3,
            server: 2,
            forbidden: 1,
            not_found: 1,
            parse: 1
        };
        results.forEach(function (res) {
            if (!res) {
                return;
            }
            if (res.ok && !res.error) {
                anyOk = true;
                return;
            }
            if ((rank[res.error] || 0) > (rank[worst] || 0)) {
                worst = res.error;
                message = res.message || "";
            }
        });
        engine._setError(slot, anyOk ? "" : worst, anyOk ? "" : message);
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
        running: engine.active && engine.configured && engine.primaryError !== Http.ERR.RATE_LIMIT
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
     * wakes it up a few seconds after the forge says the window rolls over.
     */
    readonly property Timer _resumeTimer: Timer {
        interval: Math.max(5000, engine.rateResetMs - Date.now() + 5000)
        repeat: false
        running: engine.primaryError === Http.ERR.RATE_LIMIT && engine.rateResetMs > 0
        onTriggered: {
            engine._setError("inbox", "", "");
            engine._setError("search", "", "");
            engine._setError("actions", "", "");
            engine.refreshAll(false);
        }
    }

    /**
     * Restart on any credential change.
     *
     * Debounced: a settings page binds a text field straight to this, so
     * without it every keystroke of a pasted token starts a fresh bootstrap.
     */
    readonly property Timer _restartTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: engine.start()
    }

    onAccountsJsonChanged: engine._restartTimer.restart()
    onCliTokenChanged: engine._restartTimer.restart()
}
