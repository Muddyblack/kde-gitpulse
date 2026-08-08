// Gitpulse — GitHub transport.
//
// Everything here runs on QML's own XMLHttpRequest and JSON.parse. There is no
// Python, no curl, no jq: the widget is installable as a plain plasmoid and
// works the moment it is added, on any distribution.
//
// Every call takes a node-style callback `cb(res)` where res is:
//   { ok, status, error, message, data, notModified, rate, retryAfter }
// `error` is one of ERR.* and is the only thing the UI should branch on —
// HTTP status codes stay in here.
.pragma library

var REST = "https://api.github.com";
var GRAPHQL = "https://api.github.com/graphql";
var STATUS = "https://www.githubstatus.com/api/v2";
var WEB = "https://github.com";

var API_VERSION = "2022-11-28";

/** The complete set of failure modes the UI has to render. */
var ERR = {
    NONE: "",
    NO_TOKEN: "no_token", // nothing configured yet
    AUTH: "auth", // 401 — token invalid, expired or revoked
    FORBIDDEN: "forbidden", // 403 — token lacks the scope for this endpoint
    RATE_LIMIT: "rate_limit", // 403/429 — primary or secondary limit
    NOT_FOUND: "not_found", // 404 — also what GitHub returns for "no access"
    SERVER: "server", // 5xx — GitHub's problem, retry later
    OFFLINE: "offline", // no network / DNS / TLS failure
    PARSE: "parse" // 200 with a body we could not read
};

/**
 * Runtime self-check.
 *
 * The entire transport rests on the QML engine providing XMLHttpRequest inside
 * a `.pragma library` script. That holds for Plasma and for Quickshell, but if
 * it ever stops holding the widget should say so plainly instead of looking
 * like every request silently failed.
 */
function capabilities() {
    return {
        xhr: typeof XMLHttpRequest !== "undefined",
        json: typeof JSON !== "undefined"
    };
}

// ── conditional-request cache ───────────────────────────────────────────────
//
// GitHub does not count a 304 against the rate limit, so every GET carries the
// previous ETag. This is the single reason the widget can poll the inbox every
// 60 s and still use a rounding error of the hourly budget.

var _cache = {};

function clearCache() {
    _cache = {};
}

/** Drop cached bodies for one prefix — used when the token or filters change. */
function invalidate(prefix) {
    for (var k in _cache) {
        if (!prefix || k.indexOf(prefix) === 0)
            delete _cache[k];
    }
}

// ── core request ────────────────────────────────────────────────────────────

function _rateFrom(xhr) {
    function num(h) {
        var v = xhr.getResponseHeader(h);
        return v === null || v === "" ? -1 : parseInt(v, 10);
    }
    var limit = num("x-ratelimit-limit");
    if (limit < 0)
        return null;
    return {
        limit: limit,
        remaining: num("x-ratelimit-remaining"),
        used: num("x-ratelimit-used"),
        reset: num("x-ratelimit-reset") // epoch seconds
    };
}

function _messageOf(body) {
    if (!body)
        return "";
    try {
        var j = JSON.parse(body);
        return j.message || "";
    } catch (e) {
        return "";
    }
}

function _classify(xhr, rate) {
    var s = xhr.status;
    if (s === 0)
        return ERR.OFFLINE;
    if (s >= 200 && s < 300)
        return ERR.NONE;
    if (s === 304)
        return ERR.NONE;
    if (s === 401)
        return ERR.AUTH;
    if (s === 429)
        return ERR.RATE_LIMIT;
    if (s === 403) {
        // A 403 is either "you are out of budget" or "your token cannot do
        // this". Only the first is worth backing off for, so tell them apart
        // by the counter and the message rather than treating both as fatal.
        if (rate && rate.remaining === 0)
            return ERR.RATE_LIMIT;
        var m = _messageOf(xhr.responseText).toLowerCase();
        if (m.indexOf("rate limit") >= 0 || m.indexOf("abuse") >= 0)
            return ERR.RATE_LIMIT;
        return ERR.FORBIDDEN;
    }
    if (s === 404)
        return ERR.NOT_FOUND;
    if (s >= 500)
        return ERR.SERVER;
    return ERR.SERVER;
}

/**
 * One HTTP call.
 *
 * opts: { url, method, token, body, accept, conditional, cacheKey }
 * Returns the XMLHttpRequest so callers can abort() an in-flight poll when the
 * popup closes or the token changes.
 */
function request(opts, cb) {
    var method = opts.method || "GET";
    var url = opts.url;
    var key = opts.cacheKey || url;
    var conditional = opts.conditional !== false && method === "GET";
    var cached = conditional ? _cache[key] : null;

    var xhr = new XMLHttpRequest();
    xhr.open(method, url);
    xhr.setRequestHeader("Accept", opts.accept || "application/vnd.github+json");
    xhr.setRequestHeader("X-GitHub-Api-Version", API_VERSION);
    if (opts.token)
        xhr.setRequestHeader("Authorization", "Bearer " + opts.token);
    if (opts.body)
        xhr.setRequestHeader("Content-Type", "application/json");
    if (cached && cached.etag)
        xhr.setRequestHeader("If-None-Match", cached.etag);
    else if (cached && cached.lastModified)
        xhr.setRequestHeader("If-Modified-Since", cached.lastModified);

    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;

        var rate = _rateFrom(xhr);
        var error = _classify(xhr, rate);
        var retryAfter = parseInt(xhr.getResponseHeader("retry-after") || "0", 10) || 0;

        if (xhr.status === 304 && cached) {
            cb({
                ok: true,
                status: 304,
                error: ERR.NONE,
                message: "",
                data: cached.body,
                notModified: true,
                rate: rate,
                retryAfter: 0
            });
            return;
        }

        if (error !== ERR.NONE) {
            cb({
                ok: false,
                status: xhr.status,
                error: error,
                message: _messageOf(xhr.responseText),
                // Serving the stale body beats blanking the list: an expired
                // token should not make it look like the inbox is empty.
                data: cached ? cached.body : null,
                notModified: false,
                rate: rate,
                retryAfter: retryAfter
            });
            return;
        }

        var parsed = null;
        if (xhr.responseText && xhr.responseText.length) {
            try {
                parsed = JSON.parse(xhr.responseText);
            } catch (e) {
                cb({
                    ok: false,
                    status: xhr.status,
                    error: ERR.PARSE,
                    message: String(e),
                    data: null,
                    notModified: false,
                    rate: rate,
                    retryAfter: 0
                });
                return;
            }
        }

        if (conditional) {
            var etag = xhr.getResponseHeader("etag");
            var lastMod = xhr.getResponseHeader("last-modified");
            if (etag || lastMod)
                _cache[key] = {
                    etag: etag,
                    lastModified: lastMod,
                    body: parsed,
                    at: Date.now()
                };
        }

        cb({
            ok: true,
            status: xhr.status,
            error: ERR.NONE,
            message: "",
            data: parsed,
            notModified: false,
            rate: rate,
            retryAfter: 0
        });
    };

    try {
        xhr.send(opts.body ? JSON.stringify(opts.body) : undefined);
    } catch (e) {
        // Qt raises synchronously on a malformed URL rather than reporting it
        // through readyState, so this branch is not dead code.
        cb({
            ok: false,
            status: 0,
            error: ERR.OFFLINE,
            message: String(e),
            data: null,
            notModified: false,
            rate: null,
            retryAfter: 0
        });
    }
    return xhr;
}

/** Fan out N independent calls and fire once, in order. */
function all(tasks, cb) {
    var results = new Array(tasks.length);
    var left = tasks.length;
    if (!left) {
        cb([]);
        return [];
    }
    var handles = [];
    tasks.forEach(function (task, i) {
        handles.push(task(function (res) {
            results[i] = res;
            if (--left === 0)
                cb(results);
        }));
    });
    return handles;
}

function _noToken(cb) {
    cb({
        ok: false,
        status: 0,
        error: ERR.NO_TOKEN,
        message: "",
        data: null,
        notModified: false,
        rate: null,
        retryAfter: 0
    });
    return null;
}

// ── REST endpoints ──────────────────────────────────────────────────────────

/** The signed-in user. Doubles as the token validity check. */
function viewer(token, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/user",
        token: token
    }, cb);
}

function notifications(token, opts, cb) {
    if (!token)
        return _noToken(cb);
    var o = opts || {};
    var q = ["per_page=" + (o.perPage || 50)];
    q.push("all=" + (o.includeRead ? "true" : "false"));
    if (o.participating)
        q.push("participating=true");
    return request({
        url: REST + "/notifications?" + q.join("&"),
        token: token
    }, cb);
}

function markThreadRead(token, threadId, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/notifications/threads/" + threadId,
        method: "PATCH",
        token: token,
        conditional: false
    }, cb);
}

function markAllRead(token, lastReadAt, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/notifications",
        method: "PUT",
        token: token,
        conditional: false,
        body: {
            last_read_at: lastReadAt || new Date().toISOString(),
            read: true
        }
    }, cb);
}

function unsubscribeThread(token, threadId, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/notifications/threads/" + threadId + "/subscription",
        method: "DELETE",
        token: token,
        conditional: false
    }, cb);
}

/**
 * Issue/PR search. One request covers every repository the user touches, which
 * is why this is used instead of walking repos.
 */
function searchIssues(token, query, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/search/issues?per_page=30&sort=updated&order=desc&advanced_search=true&q=" + encodeURIComponent(query),
        token: token
    }, cb);
}

/**
 * Repositories the user pushed to most recently — the Actions watch list.
 *
 * `organization_member` is opt-in: it pulls in every repository of every org
 * you belong to, so a single large org floods the tab with pipelines you have
 * never touched.
 */
function recentRepos(token, count, includeOrgs, cb) {
    if (!token)
        return _noToken(cb);
    var affiliation = includeOrgs ? "owner,collaborator,organization_member" : "owner,collaborator";
    return request({
        url: REST + "/user/repos?sort=pushed&direction=desc&per_page=" + (count || 6) + "&affiliation=" + affiliation,
        token: token
    }, cb);
}

/**
 * The user's own public event feed.
 *
 * Only used to work out what time of day they tend to work. Capped by GitHub
 * at roughly 90 days and 300 events, and public-only — which is fine for a
 * rhythm, and would not be fine for a total.
 */
function userEvents(token, login, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/users/" + encodeURIComponent(login) + "/events/public?per_page=100",
        token: token
    }, cb);
}

function workflowRuns(token, fullName, perPage, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/repos/" + fullName + "/actions/runs?per_page=" + (perPage || 3),
        token: token
    }, cb);
}

function rerunWorkflow(token, fullName, runId, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/repos/" + fullName + "/actions/runs/" + runId + "/rerun",
        method: "POST",
        token: token,
        conditional: false
    }, cb);
}

/**
 * Copilot spend on the enhanced billing platform.
 *
 * There is no public endpoint for a personal Copilot completion count — that
 * data only exists for organisation and enterprise admins. This returns the
 * billing usage report, which does include Copilot premium requests, and the
 * UI is expected to render FORBIDDEN/NOT_FOUND as "not available for this
 * account" rather than as an error.
 */
function billingUsage(token, login, year, month, cb) {
    if (!token)
        return _noToken(cb);
    var q = [];
    if (year)
        q.push("year=" + year);
    if (month)
        q.push("month=" + month);
    return request({
        url: REST + "/users/" + encodeURIComponent(login) + "/settings/billing/usage" + (q.length ? "?" + q.join("&") : ""),
        token: token
    }, cb);
}

/** Organisation-wide Copilot metrics — requires an org admin token. */
function copilotOrgMetrics(token, org, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/orgs/" + encodeURIComponent(org) + "/copilot/metrics",
        token: token
    }, cb);
}

/** Organisation Copilot seat breakdown — requires an org admin token. */
function copilotOrgBilling(token, org, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: REST + "/orgs/" + encodeURIComponent(org) + "/copilot/billing",
        token: token
    }, cb);
}

// ── GraphQL ─────────────────────────────────────────────────────────────────

/**
 * Profile, contribution calendar and language mix in a single round trip.
 *
 * REST cannot return the contribution calendar at all, so the Profile tab is
 * the one place a GraphQL call is unavoidable. A classic token needs `read:user`;
 * a fine-grained token cannot use GraphQL for this at all, which the UI reports
 * as "heatmap unavailable" instead of failing the whole tab.
 */
// `viewer`, not `user(login:)`. The Profile tab is always about whoever the
// token belongs to, and asking for yourself needs strictly fewer permissions
// than asking about a named user — which is the difference between this tab
// working and not on a lot of tokens.
var PROFILE_QUERY = "query{" + "viewer{" + "login name bio avatarUrl url company location createdAt websiteUrl" + " followers{totalCount} following{totalCount} gists{totalCount}" + " starredRepositories{totalCount}" + " organizations(first:1){totalCount}" + " sponsors{totalCount}" + " repositories(first:100,ownerAffiliations:OWNER,isFork:false,orderBy:{field:PUSHED_AT,direction:DESC}){" + "  totalCount" + "  nodes{ nameWithOwner stargazerCount" + "    languages(first:6,orderBy:{field:SIZE,direction:DESC}){edges{size node{name color}}}" + "  }" + " }" + " contributionsCollection{" + "  totalCommitContributions totalIssueContributions" + "  totalPullRequestContributions totalPullRequestReviewContributions" + "  restrictedContributionsCount" + "  contributionCalendar{ totalContributions weeks{ contributionDays{ date contributionCount weekday } } }" + " }" + "}}";

/** Returns the user node, whichever query shape produced it. */
function profileNode(payload) {
    var d = payload && payload.data;
    if (!d)
        return null;
    return d.viewer || d.user || null;
}

function profileGraph(token, login, cb) {
    if (!token)
        return _noToken(cb);
    return request({
        url: GRAPHQL,
        method: "POST",
        token: token,
        conditional: false,
        body: {
            query: PROFILE_QUERY
        }
    }, function (res) {
        // GraphQL answers 200 even when it refuses, so unwrap the envelope and
        // translate it into the same error vocabulary as the REST calls.
        if (res.ok && res.data && res.data.errors && res.data.errors.length && !profileNode(res.data)) {
            var first = res.data.errors[0] || {};
            var type = String(first.type || "");
            res.ok = false;
            res.message = first.message || "GraphQL error";
            res.error = type === "NOT_FOUND" ? ERR.NOT_FOUND : type === "FORBIDDEN" || type === "INSUFFICIENT_SCOPES" ? ERR.FORBIDDEN : ERR.SERVER;
        }
        cb(res);
    });
}

// ── githubstatus.com (unauthenticated) ──────────────────────────────────────
//
// No token needed, so the Status tab works before the widget is configured —
// which is exactly when a user is most likely to be wondering whether the
// problem is them or GitHub.

function serviceSummary(cb) {
    return request({
        url: STATUS + "/summary.json",
        accept: "application/json",
        cacheKey: "status:summary"
    }, cb);
}

function serviceIncidents(cb) {
    return request({
        url: STATUS + "/incidents.json",
        accept: "application/json",
        cacheKey: "status:incidents"
    }, cb);
}

// ── web URLs ────────────────────────────────────────────────────────────────

function notificationsUrl() {
    return WEB + "/notifications";
}

function repoUrl(fullName) {
    return WEB + "/" + fullName;
}

function runUrl(fullName, runId) {
    return WEB + "/" + fullName + "/actions/runs/" + runId;
}

function pullUrl(fullName, number) {
    return WEB + "/" + fullName + "/pull/" + number;
}

/**
 * Notification subjects carry an API URL, not a browser one. Rewriting it is
 * the difference between landing on the pull request and landing on JSON.
 */
function webUrlFor(apiUrl, fallbackRepo) {
    if (!apiUrl)
        return fallbackRepo ? repoUrl(fallbackRepo) : WEB;
    var u = String(apiUrl);
    if (u.indexOf(REST + "/repos/") !== 0)
        return fallbackRepo ? repoUrl(fallbackRepo) : WEB;
    var rest = u.slice((REST + "/repos/").length);
    // owner/repo/<kind>/<number> → github.com/owner/repo/<web kind>/<number>
    var parts = rest.split("/");
    if (parts.length < 4)
        return WEB + "/" + parts.slice(0, 2).join("/");
    var kind = parts[2];
    var webKind = kind === "pulls" ? "pull" : kind === "commits" ? "commit" : kind === "releases" ? "releases/tag" : kind;
    return WEB + "/" + parts[0] + "/" + parts[1] + "/" + webKind + "/" + parts.slice(3).join("/");
}
