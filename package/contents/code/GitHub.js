// Gitpulse — the GitHub provider.
//
// Implements the provider interface Forge.js dispatches to: every function
// takes an account `{ id, provider, host, token, graphqlToken, login }` and
// answers with Http.js's result envelope, where `data` is already in the
// Contract.js item shape. Nothing above this file knows what a
// `subject.latest_comment_url` is.
//
// Setting `host` to a GitHub Enterprise Server URL works: the REST base moves
// to /api/v3 and everything else follows.
.pragma library

.import "Http.js" as Http
.import "Format.js" as Fmt
.import "Contract.js" as C

var ID = "github";
var LABEL = "GitHub";
var DEFAULT_HOST = "https://github.com";

var API_VERSION = "2022-11-28";
var STATUS = "https://www.githubstatus.com/api/v2";

/** What the UI may offer for this forge. */
var CAPABILITIES = {
    inbox: true,
    pulls: true,
    issues: true,
    pipelines: true,
    profile: true,
    languages: true,
    calendar: true,
    markRead: true,
    markAllRead: true,
    unsubscribe: true,
    rerun: true,
    copilot: true,
    status: true
};

function webBase(acct) {
    var h = Http.trimHost(acct && acct.host);
    return h || DEFAULT_HOST;
}

/** github.com is the one host whose API lives on a different domain. */
function apiBase(acct) {
    var web = webBase(acct);
    if (web === DEFAULT_HOST || web === "https://www.github.com")
        return "https://api.github.com";
    return web + "/api/v3";
}

function graphqlUrl(acct) {
    var web = webBase(acct);
    if (web === DEFAULT_HOST || web === "https://www.github.com")
        return "https://api.github.com/graphql";
    return web + "/api/graphql";
}

function _get(acct, path, opts) {
    var o = opts || {};
    return {
        url: o.absolute ? path : apiBase(acct) + path,
        method: o.method || "GET",
        token: acct.token,
        body: o.body,
        accept: o.accept || "application/vnd.github+json",
        conditional: o.conditional,
        cacheKey: o.cacheKey ? acct.id + ":" + o.cacheKey : undefined,
        headers: {
            "X-GitHub-Api-Version": API_VERSION
        }
    };
}

function _profileToken(acct) {
    return acct.graphqlToken || acct.token;
}

// ── identity ────────────────────────────────────────────────────────────────

/** The signed-in user. Doubles as the token validity check. */
function viewer(acct, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    return Http.request(_get(acct, "/user"), function (res) {
        if (res.ok && res.data)
            res.data = {
                login: res.data.login,
                name: res.data.name || res.data.login,
                avatarUrl: res.data.avatar_url || "",
                url: res.data.html_url || "",
                id: res.data.node_id || res.data.id,
                raw: res.data
            };
        cb(res);
    });
}

// ── inbox ───────────────────────────────────────────────────────────────────

function inbox(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    var q = Http.query({
        per_page: o.perPage || 50,
        all: o.includeRead ? "true" : "false",
        participating: o.participating ? "true" : undefined
    });
    return Http.request(_get(acct, "/notifications" + q), function (res) {
        if (res.ok && res.data)
            res.data = res.data.map(function (raw) {
                return notification(acct, raw);
            });
        cb(res);
    });
}

function notification(acct, raw) {
    var subject = raw.subject || {};
    var repo = (raw.repository && raw.repository.full_name) || "";
    return C.item({
        // The owner's picture is what turns a wall of text into something
        // scannable — the same trick GitHub's own inbox uses.
        avatarUrl: (raw.repository && raw.repository.owner && raw.repository.owner.avatar_url) || "",
        id: acct.id + ":n:" + raw.id,
        threadId: raw.id,
        kind: C.KIND.NOTIFICATION,
        repo: repo,
        title: subject.title,
        url: webUrlFor(acct, subject.url, repo),
        subjectKey: C.subjectKey(acct.id, subject.url),
        tone: raw.unread ? C.reasonTone(raw.reason) : "muted",
        label: Fmt.reasonLabel(raw.reason),
        icon: Fmt.reasonIcon(raw.reason),
        reason: raw.reason || "",
        updatedAt: raw.updated_at || "",
        unread: !!raw.unread,
        number: C.numberFrom(subject.url),
        detail: Fmt.humanise(subject.type || ""),
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── pull requests and issues ────────────────────────────────────────────────

/**
 * One search endpoint covers every repository the user touches, which is why
 * this is used instead of walking repositories.
 */
function _search(acct, query, cb) {
    var q = Http.query({
        per_page: 30,
        sort: "updated",
        order: "desc",
        advanced_search: "true",
        q: query
    });
    return Http.request(_get(acct, "/search/issues" + q), cb);
}

// The search API does not carry diff sizes, so they are fetched in one extra
// GraphQL round trip keyed by the node ids search already handed us.
var DIFF_QUERY = "query($ids:[ID!]!){nodes(ids:$ids){... on PullRequest{id additions deletions}}}";

// `nodes(ids:)` refuses more than 100 ids; past that the whole query errors and
// every badge disappears at once, so cap it and let the tail go unbadged.
var DIFF_MAX_NODES = 100;

/** The node ids of pulls we can ask for diff sizes, capped to what the API takes. */
function pullNodeIds(pulls) {
    var ids = [];
    (pulls || []).forEach(function (p) {
        if (p && p.raw && p.raw.node_id && ids.length < DIFF_MAX_NODES)
            ids.push(p.raw.node_id);
    });
    return ids;
}

/**
 * Fold `additions`/`deletions` from a GraphQL `nodes` payload onto the pulls
 * they belong to. Separate from the request so the matching is testable without
 * a network stub — this is the only path by which a GitHub PR gets its diff.
 * Returns how many pulls were enriched.
 */
function applyDiffStats(pulls, nodes) {
    if (!pulls || !Array.isArray(nodes))
        return 0;
    var byNodeId = {};
    pulls.forEach(function (p) {
        if (p && p.raw && p.raw.node_id)
            byNodeId[p.raw.node_id] = p;
    });
    var applied = 0;
    nodes.forEach(function (node) {
        var p = node && node.id ? byNodeId[node.id] : null;
        if (!p)
            return;
        p.additions = typeof node.additions === "number" ? node.additions : null;
        p.deletions = typeof node.deletions === "number" ? node.deletions : null;
        applied++;
    });
    return applied;
}

function work(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    var queries = [];
    if (o.pulls) {
        queries.push({
            review: true,
            q: "is:open is:pr archived:false review-requested:@me"
        });
        queries.push({
            review: false,
            q: "is:open is:pr archived:false author:@me"
        });
    }
    if (o.issues)
        queries.push({
            review: false,
            q: "is:open is:issue archived:false involves:@me"
        });
    if (!queries.length)
        return Http.empty(cb, {
            pulls: [],
            issues: []
        });

    var tasks = queries.map(function (spec) {
        return function (done) {
            return _search(acct, spec.q, done);
        };
    });

    return Http.all(tasks, function (results) {
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
            var list = (res.data && res.data.items) || [];
            list.forEach(function (raw) {
                var it = searchItem(acct, raw);
                if (queries[i].review)
                    it.reviewRequested = true;
                // The same PR comes back from both queries; keep one record
                // and let reviewRequested stick.
                var seen = byId[it.id];
                if (seen) {
                    seen.reviewRequested = seen.reviewRequested || it.reviewRequested;
                    return;
                }
                byId[it.id] = it;
                if (it.kind === C.KIND.PULL)
                    pulls.push(it);
                else
                    issues.push(it);
            });
        });

        if (firstError && !pulls.length && !issues.length) {
            cb(firstError);
            return;
        }

        var finish = function () {
            cb({
                ok: true,
                status: 200,
                error: firstError ? firstError.error : "",
                message: firstError ? firstError.message : "",
                data: {
                    pulls: pulls,
                    issues: issues
                },
                notModified: false,
                rate: results.length ? results[0].rate : null,
                retryAfter: 0
            });
        };

        var nodeIds = pullNodeIds(pulls);
        if (!nodeIds.length || !_profileToken(acct)) {
            finish();
            return;
        }

        _graphql(acct, DIFF_QUERY, {
            ids: nodeIds
        }, function (gqlRes) {
            var payload = graphqlPayload(gqlRes);
            if (payload)
                applyDiffStats(pulls, payload.nodes);
            finish();
        });
    });
}

function searchItem(acct, raw) {
    var isPull = !!raw.pull_request;
    var repo = C.repoFromIssueUrl(raw.repository_url || raw.html_url);
    var merged = isPull && !!raw.pull_request.merged_at;
    var draft = !!raw.draft;
    var author = (raw.user && raw.user.login) || "";
    var assigned = (raw.assignees || []).some(function (a) {
        return a.login === acct.login;
    });

    if (isPull)
        return C.item({
            avatarUrl: (raw.user && raw.user.avatar_url) || "",
            id: acct.id + ":p:" + raw.id,
            kind: C.KIND.PULL,
            repo: repo,
            title: raw.title,
            url: raw.html_url,
            subjectKey: C.subjectKey(acct.id, raw.pull_request.url || raw.url),
            tone: Fmt.pullTone(raw.state, draft, merged),
            label: Fmt.pullLabel(raw.state, draft, merged),
            icon: Fmt.pullIcon(raw.state, draft, merged),
            actor: author,
            updatedAt: raw.updated_at || "",
            number: "#" + raw.number,
            detail: raw.comments ? raw.comments + " comments" : "",
            yours: author === acct.login,
            draft: draft,
            merged: merged,
            assigned: assigned,
            pullNumber: raw.number,
            account: acct.id,
            provider: ID,
            host: webBase(acct),
            additions: typeof raw.additions === "number" ? raw.additions : null,
            deletions: typeof raw.deletions === "number" ? raw.deletions : null,
            raw: raw
        });

    return C.item({
        avatarUrl: (raw.user && raw.user.avatar_url) || "",
        id: acct.id + ":i:" + raw.id,
        kind: C.KIND.ISSUE,
        repo: repo,
        title: raw.title,
        url: raw.html_url,
        subjectKey: C.subjectKey(acct.id, raw.url),
        tone: raw.state === "closed" ? "muted" : assigned ? "accent" : "positive",
        label: raw.state === "closed" ? "closed" : assigned ? "assigned" : "open",
        icon: raw.state === "closed" ? "dialog-ok" : "view-task",
        actor: author,
        updatedAt: raw.updated_at || "",
        number: "#" + raw.number,
        detail: C.labelNames(raw.labels).join(", "),
        yours: author === acct.login,
        assigned: assigned,
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── Actions ─────────────────────────────────────────────────────────────────

/**
 * Repositories the user pushed to most recently — the Actions watch list.
 *
 * `organization_member` is opt-in: it pulls in every repository of every org
 * you belong to, so a single large org floods the tab with pipelines you have
 * never touched.
 */
function _recentRepos(acct, count, includeOrgs, cb) {
    var q = Http.query({
        sort: "pushed",
        direction: "desc",
        per_page: count || 6,
        affiliation: includeOrgs ? "owner,collaborator,organization_member" : "owner,collaborator"
    });
    return Http.request(_get(acct, "/user/repos" + q), cb);
}

function pipelines(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    if (o.repos && o.repos.length)
        return _runsFor(acct, o.repos, cb);

    return _recentRepos(acct, o.count, o.includeOrgs, function (res) {
        if (!res.ok) {
            cb(res);
            return;
        }
        _runsFor(acct, (res.data || []).map(function (r) {
            return r.full_name;
        }), cb);
    });
}

function _runsFor(acct, names, cb) {
    if (!names.length)
        return Http.empty(cb, []);
    var tasks = names.map(function (name) {
        return function (done) {
            return Http.request(_get(acct, "/repos/" + name + "/actions/runs?per_page=3"), done);
        };
    });
    return Http.all(tasks, function (results) {
        var runs = [];
        var firstError = null;
        results.forEach(function (res, i) {
            if (!res.ok) {
                // A single archived or permission-denied repository must not
                // take the whole tab down with it.
                if (!firstError && res.error !== Http.ERR.NOT_FOUND && res.error !== Http.ERR.FORBIDDEN)
                    firstError = res;
                return;
            }
            ((res.data && res.data.workflow_runs) || []).forEach(function (raw) {
                runs.push(run(acct, raw, names[i]));
            });
        });
        cb({
            ok: true,
            status: 200,
            error: firstError ? firstError.error : "",
            message: firstError ? firstError.message : "",
            data: runs,
            notModified: false,
            rate: results.length ? results[0].rate : null,
            retryAfter: 0
        });
    });
}

function run(acct, raw, fallbackRepo) {
    var repo = (raw.repository && raw.repository.full_name) || fallbackRepo || "";
    var actor = (raw.actor && raw.actor.login) || (raw.triggering_actor && raw.triggering_actor.login) || "";
    // A run triggered by a pull request carries it here, which lets the UI
    // offer "open the pull request" instead of only the run log.
    var prs = raw.pull_requests || [];
    return C.item({
        pullNumber: prs.length ? prs[0].number : 0,
        avatarUrl: (raw.actor && raw.actor.avatar_url) || (raw.repository && raw.repository.owner && raw.repository.owner.avatar_url) || "",
        id: acct.id + ":r:" + raw.id,
        runId: raw.id,
        kind: C.KIND.RUN,
        repo: repo,
        title: raw.name || raw.display_title || "workflow",
        url: raw.html_url || (webBase(acct) + "/" + repo + "/actions/runs/" + raw.id),
        tone: Fmt.runTone(raw.status, raw.conclusion),
        label: Fmt.runLabel(raw.status, raw.conclusion),
        icon: Fmt.runIcon(raw.status, raw.conclusion),
        actor: actor,
        updatedAt: raw.updated_at || raw.created_at || "",
        number: raw.run_number ? "#" + raw.run_number : "",
        detail: raw.head_branch || "",
        // "Yours" decides whether a red pipeline reaches the badge. A failure
        // on a colleague's branch is information; a failure on yours is a task.
        yours: !acct.login || actor === acct.login || raw.head_branch === "main" || raw.head_branch === "master",
        running: raw.status === "in_progress" || raw.status === "queued" || raw.status === "pending",
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── mutations ───────────────────────────────────────────────────────────────

function markRead(acct, it, cb) {
    return Http.request(_get(acct, "/notifications/threads/" + it.threadId, {
        method: "PATCH",
        conditional: false
    }), cb);
}

function markAllRead(acct, lastReadAt, cb) {
    return Http.request(_get(acct, "/notifications", {
        method: "PUT",
        conditional: false,
        body: {
            last_read_at: lastReadAt || new Date().toISOString(),
            read: true
        }
    }), cb);
}

function unsubscribe(acct, it, cb) {
    return Http.request(_get(acct, "/notifications/threads/" + it.threadId + "/subscription", {
        method: "DELETE",
        conditional: false
    }), cb);
}

function rerun(acct, it, cb) {
    return Http.request(_get(acct, "/repos/" + it.repo + "/actions/runs/" + it.runId + "/rerun", {
        method: "POST",
        conditional: false
    }), cb);
}

// ── profile ─────────────────────────────────────────────────────────────────
//
// REST cannot return the contribution calendar at all, so the Profile tab is
// the one place a GraphQL call is unavoidable. A classic token needs
// `read:user`; a fine-grained token is frequently refused, which the UI reports
// as "profile unavailable" instead of failing the whole widget.
//
// `viewer`, not `user(login:)`. The Profile tab is always about whoever the
// token belongs to, and asking for yourself needs strictly fewer permissions
// than asking about a named user — which is the difference between this tab
// working and not on a lot of tokens.
var PROFILE_QUERY = "query{" + "viewer{" + "id login name bio avatarUrl url company location createdAt websiteUrl" + " followers{totalCount} following{totalCount} gists{totalCount}" + " starredRepositories{totalCount}" + " organizations(first:1){totalCount}" + " sponsors{totalCount}" + " repositories(first:100,ownerAffiliations:OWNER,isFork:false,orderBy:{field:PUSHED_AT,direction:DESC}){" + "  totalCount" + "  nodes{ name nameWithOwner stargazerCount pushedAt" + "    languages(first:6,orderBy:{field:SIZE,direction:DESC}){edges{size node{name color}}}" + "  }" + " }" + " contributionsCollection{" + "  totalCommitContributions totalIssueContributions" + "  totalPullRequestContributions totalPullRequestReviewContributions" + "  restrictedContributionsCount" + "  contributionCalendar{ totalContributions weeks{ contributionDays{ date contributionCount } } }" + " }" + "}}";

/**
 * The response body of a GraphQL call is the whole envelope, so every reader
 * has to step down through `.data` to reach the fields it asked for. Spelling
 * that out at each call site is how a reader ends up one level too high and
 * silently sees `undefined` — name it once.
 */
function graphqlPayload(res) {
    return res && res.ok && res.data && res.data.data ? res.data.data : null;
}

/** Returns the user node, whichever query shape produced it. */
function profileNode(payload) {
    var d = payload && payload.data;
    if (!d)
        return null;
    return d.viewer || d.user || null;
}

function _graphql(acct, query, variables, cb) {
    return Http.request({
        url: graphqlUrl(acct),
        method: "POST",
        token: _profileToken(acct),
        conditional: false,
        accept: "application/json",
        body: {
            query: query,
            variables: variables || {}
        }
    }, function (res) {
        // GraphQL answers 200 even when it refuses, so unwrap the envelope and
        // translate it into the same error vocabulary as the REST calls.
        if (res.ok && res.data && res.data.errors && res.data.errors.length && !profileNode(res.data)) {
            var first = res.data.errors[0] || {};
            var type = String(first.type || "");
            res.ok = false;
            res.message = first.message || "GraphQL error";
            res.error = type === "NOT_FOUND" ? Http.ERR.NOT_FOUND : type === "FORBIDDEN" || type === "INSUFFICIENT_SCOPES" ? Http.ERR.FORBIDDEN : Http.ERR.SERVER;
        }
        cb(res);
    });
}

function profile(acct, cb) {
    if (!_profileToken(acct))
        return Http.noToken(cb);
    return _graphql(acct, PROFILE_QUERY, null, function (res) {
        if (!res.ok) {
            cb(res);
            return;
        }
        var user = profileNode(res.data);
        if (!user) {
            res.ok = false;
            res.error = Http.ERR.NOT_FOUND;
            cb(res);
            return;
        }
        res.data = {
            profile: _profileOf(user),
            calendar: _calendarOf(user.contributionsCollection),
            languages: _languagesOf(user),
            repos: ((user.repositories && user.repositories.nodes) || []).map(function (r) {
                return r.nameWithOwner;
            }),
            viewerId: user.id
        };
        cb(res);
    });
}

function _profileOf(user) {
    var c = user.contributionsCollection || {};
    var repos = (user.repositories && user.repositories.nodes) || [];
    return C.profile({
        login: user.login,
        name: user.name,
        bio: user.bio,
        avatarUrl: user.avatarUrl,
        url: user.url,
        company: user.company,
        location: user.location,
        website: user.websiteUrl,
        createdAt: user.createdAt,
        followers: _count(user.followers),
        following: _count(user.following),
        gists: _count(user.gists),
        starred: _count(user.starredRepositories),
        orgs: _count(user.organizations),
        sponsors: _count(user.sponsors),
        repos: (user.repositories && user.repositories.totalCount) || repos.length,
        starsEarned: repos.reduce(function (n, r) {
            return n + (r.stargazerCount || 0);
        }, 0),
        commits: c.totalCommitContributions || 0,
        pulls: c.totalPullRequestContributions || 0,
        issues: c.totalIssueContributions || 0,
        reviews: c.totalPullRequestReviewContributions || 0,
        privateContributions: c.restrictedContributionsCount || 0,
        provider: ID
    });
}

function _count(node) {
    return (node && node.totalCount) || 0;
}

function _calendarOf(collection) {
    var cal = collection && collection.contributionCalendar;
    if (!cal || !cal.weeks)
        return null;
    var days = [];
    cal.weeks.forEach(function (w) {
        (w.contributionDays || []).forEach(function (d) {
            days.push({
                date: d.date,
                count: d.contributionCount
            });
        });
    });
    return C.calendar(days, cal.totalContributions);
}

/** Colours come from the API, so nothing here hard-codes a language palette. */
function _languagesOf(user) {
    var repos = (user.repositories && user.repositories.nodes) || [];
    var flat = [];
    repos.forEach(function (r) {
        ((r.languages && r.languages.edges) || []).forEach(function (e) {
            if (e && e.node)
                flat.push({
                    name: e.node.name,
                    bytes: e.size || 0,
                    color: e.node.color || ""
                });
        });
    });
    return C.languages(flat, 6);
}

// ── when I commit ───────────────────────────────────────────────────────────

/**
 * Real commit timestamps for the hour dial, in one GraphQL round trip.
 *
 * The contribution calendar has no clock on it — it knows a day had eleven
 * contributions and nothing about when. This asks the default branch of the
 * few repositories the user actually pushed to recently for their own commits'
 * `committedDate`, aliased into a single query so the whole dial costs one
 * request on the slow timer rather than one per repository.
 */
var CLOCK_REPOS = 8;
var CLOCK_DAYS = 180;

function clock(acct, hint, cb) {
    var token = _profileToken(acct);
    var names = (hint && hint.repos) || [];
    var uid = hint && hint.viewerId;
    if (!token || !uid || !names.length)
        return Http.empty(cb, null);

    var picked = names.slice(0, CLOCK_REPOS);
    var since = new Date(Date.now() - CLOCK_DAYS * 86400000).toISOString();
    var fields = picked.map(function (full, i) {
        var parts = String(full).split("/");
        return "r" + i + ": repository(owner:\"" + parts[0] + "\", name:\"" + parts[1] + "\"){" + "defaultBranchRef{target{... on Commit{" + "history(since:$since, author:{id:$uid}, first:100){nodes{committedDate}}" + "}}}}";
    }).join(" ");

    return _graphql(acct, "query($uid:ID!,$since:GitTimestamp!){" + fields + "}", {
        uid: uid,
        since: since
    }, function (res) {
        if (!res.ok) {
            cb(res);
            return;
        }
        var payload = res.data && res.data.data;
        if (!payload) {
            cb({
                ok: true,
                status: 200,
                error: "",
                message: "",
                data: null,
                notModified: false,
                rate: res.rate,
                retryAfter: 0
            });
            return;
        }
        var samples = [];
        picked.forEach(function (_, i) {
            var repo = payload["r" + i];
            var history = repo && repo.defaultBranchRef && repo.defaultBranchRef.target && repo.defaultBranchRef.target.history;
            ((history && history.nodes) || []).forEach(function (n) {
                samples.push({
                    at: n.committedDate,
                    count: 1
                });
            });
        });
        res.data = C.clock(samples);
        cb(res);
    });
}

/**
 * Fallback dial, from the public event feed.
 *
 * Capped by GitHub at roughly 90 days and 300 events, and public-only — which
 * is fine for a rhythm, and would not be fine for a total. Used when the
 * token cannot do GraphQL, so the dial degrades instead of disappearing.
 */
function events(acct, cb) {
    if (!acct.token || !acct.login)
        return Http.empty(cb, null);
    return Http.request(_get(acct, "/users/" + encodeURIComponent(acct.login) + "/events/public?per_page=100"), function (res) {
        if (res.ok && res.data)
            res.data = C.clock((res.data || []).map(function (e) {
                return {
                    at: e.created_at,
                    // A push of nine commits is nine commits at that hour, not
                    // one event — the dial is about commits.
                    count: e.type === "PushEvent" && e.payload ? Math.max(1, e.payload.distinct_size || e.payload.size || 1) : 1
                };
            }));
        cb(res);
    });
}

// ── Copilot ─────────────────────────────────────────────────────────────────

/**
 * Copilot spend on the enhanced billing platform.
 *
 * There is no public endpoint for a personal Copilot completion count — that
 * data only exists for organisation and enterprise admins. This returns the
 * billing usage report, which does include Copilot premium requests, and the
 * UI is expected to render FORBIDDEN/NOT_FOUND as "not available for this
 * account" rather than as an error.
 */
function billingUsage(acct, year, month, cb) {
    if (!acct.token || !acct.login)
        return Http.noToken(cb);
    var q = Http.query({
        year: year,
        month: month
    });
    return Http.request(_get(acct, "/users/" + encodeURIComponent(acct.login) + "/settings/billing/usage" + q), cb);
}

/** Organisation-wide Copilot metrics — requires an org admin token. */
function copilotOrgMetrics(acct, org, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    return Http.request(_get(acct, "/orgs/" + encodeURIComponent(org) + "/copilot/metrics"), cb);
}

// ── githubstatus.com (unauthenticated) ──────────────────────────────────────
//
// No token needed, so the Status tab works before the widget is configured —
// which is exactly when a user is most likely to be wondering whether the
// problem is them or GitHub.

function serviceSummary(cb) {
    return Http.request({
        url: STATUS + "/summary.json",
        accept: "application/json",
        cacheKey: "status:summary"
    }, cb);
}

function serviceIncidents(cb) {
    return Http.request({
        url: STATUS + "/incidents.json",
        accept: "application/json",
        cacheKey: "status:incidents"
    }, cb);
}

// ── web URLs ────────────────────────────────────────────────────────────────

function notificationsUrl(acct) {
    return webBase(acct) + "/notifications";
}

function repoUrl(acct, fullName) {
    return webBase(acct) + "/" + fullName;
}

/**
 * Notification subjects carry an API URL, not a browser one. Rewriting it is
 * the difference between landing on the pull request and landing on JSON.
 */
function webUrlFor(acct, apiUrl, fallbackRepo) {
    var web = webBase(acct);
    if (!apiUrl)
        return fallbackRepo ? repoUrl(acct, fallbackRepo) : web;
    var prefix = apiBase(acct) + "/repos/";
    var u = String(apiUrl);
    if (u.indexOf(prefix) !== 0)
        return fallbackRepo ? repoUrl(acct, fallbackRepo) : web;
    // owner/repo/<kind>/<number> → <web>/owner/repo/<web kind>/<number>
    var parts = u.slice(prefix.length).split("/");
    if (parts.length < 4)
        return web + "/" + parts.slice(0, 2).join("/");
    var kind = parts[2];
    var webKind = kind === "pulls" ? "pull" : kind === "commits" ? "commit" : kind === "releases" ? "releases/tag" : kind;
    return web + "/" + parts[0] + "/" + parts[1] + "/" + webKind + "/" + parts.slice(3).join("/");
}
