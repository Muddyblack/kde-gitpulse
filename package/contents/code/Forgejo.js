// Gitpulse — the Codeberg / Forgejo / Gitea provider.
//
// Same interface as GitHub.js, over Forgejo's REST v1 API. Codeberg is the
// default host; any Forgejo or Gitea instance works by changing `host`, since
// the two share this API surface.
//
// Forgejo modelled its API on GitHub's, so the payloads are close — but not
// identical, and the three differences that matter are handled here:
//   · notifications carry no `reason`, so it is inferred from the subject type
//   · issues and pull requests come from one search endpoint with flags
//   · the contribution heatmap is a first-class endpoint, and a far better
//     source than anything GitHub exposes over REST
.pragma library

.import "Http.js" as Http
.import "Format.js" as Fmt
.import "Contract.js" as C

var ID = "codeberg";
var LABEL = "Codeberg";
var DEFAULT_HOST = "https://codeberg.org";

var CAPABILITIES = {
    inbox: true,
    pulls: true,
    issues: true,
    // Forgejo Actions exists from v1.19 and older instances simply 404, which
    // the Actions tab already treats as "this repository has no pipelines".
    pipelines: true,
    profile: true,
    languages: true,
    calendar: true,
    markRead: true,
    markAllRead: true,
    unsubscribe: true,
    rerun: false,
    copilot: false,
    status: false
};

function webBase(acct) {
    return Http.trimHost(acct && acct.host) || DEFAULT_HOST;
}

function apiBase(acct) {
    return webBase(acct) + "/api/v1";
}

function _req(acct, path, opts) {
    var o = opts || {};
    return {
        url: apiBase(acct) + path,
        method: o.method || "GET",
        token: acct.token,
        // Forgejo accepts "token <t>" and "Bearer <t>"; Bearer is the one that
        // also works on Gitea 1.20+ and on Codeberg.
        scheme: "Bearer",
        body: o.body,
        accept: "application/json",
        conditional: o.conditional,
        cacheKey: o.cacheKey ? acct.id + ":" + o.cacheKey : undefined
    };
}

// ── identity ────────────────────────────────────────────────────────────────

function viewer(acct, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    return Http.request(_req(acct, "/user"), function (res) {
        if (res.ok && res.data)
            res.data = {
                login: res.data.login,
                name: res.data.full_name || res.data.login,
                avatarUrl: res.data.avatar_url || "",
                url: res.data.html_url || (webBase(acct) + "/" + res.data.login),
                id: res.data.id,
                raw: res.data
            };
        cb(res);
    });
}

// ── inbox ───────────────────────────────────────────────────────────────────

/**
 * Forgejo notifications have a subject type but no reason.
 *
 * Rather than invent a fourth vocabulary, the subject type is mapped onto the
 * GitHub reason that means the same thing to the badge. "Somebody is waiting
 * on you" is then decided identically on all three forges.
 */
var SUBJECT_REASON = {
    Issue: "subscribed",
    Pull: "review_requested",
    Commit: "comment",
    Repository: "subscribed",
    Release: "state_change"
};

function inbox(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    var q = Http.query({
        all: o.includeRead ? "true" : "false",
        // Spelled with a hyphen — Forgejo's parameter is "status-types", and
        // an underscore is silently ignored, which meant the "include read"
        // toggle returned unread threads either way.
        //
        // There is deliberately no `participating` here: Forgejo's
        // /notifications takes all, status-types, subject-type, since, before,
        // page and limit, and nothing else. Sending one it does not know is
        // not an error, it is just a setting that quietly does nothing.
        "status-types": o.includeRead ? "unread,read" : "unread",
        limit: o.perPage || 50
    });
    return Http.request(_req(acct, "/notifications" + q), function (res) {
        if (res.ok && res.data)
            res.data = (res.data || []).map(function (raw) {
                return notification(acct, raw);
            });
        cb(res);
    });
}

function notification(acct, raw) {
    var subject = raw.subject || {};
    var repo = (raw.repository && raw.repository.full_name) || "";
    var reason = SUBJECT_REASON[subject.type] || "subscribed";
    var unread = raw.unread !== false;
    return C.item({
        avatarUrl: (raw.repository && raw.repository.owner && raw.repository.owner.avatar_url) || "",
        id: acct.id + ":n:" + raw.id,
        threadId: raw.id,
        kind: C.KIND.NOTIFICATION,
        repo: repo,
        title: subject.title,
        url: subject.html_url || webUrlFor(acct, subject.url, repo),
        subjectKey: C.subjectKey(acct.id, subject.html_url || subject.url),
        tone: unread ? C.reasonTone(reason) : "muted",
        label: Fmt.reasonLabel(reason),
        icon: Fmt.reasonIcon(reason),
        reason: reason,
        updatedAt: raw.updated_at || "",
        unread: unread,
        number: C.numberFrom(subject.html_url || subject.url),
        detail: Fmt.humanise(subject.type || ""),
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── pull requests and issues ────────────────────────────────────────────────

function work(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    var specs = [];
    if (o.pulls) {
        specs.push({
            slot: "pulls",
            review: true,
            path: "/repos/issues/search" + Http.query({
                type: "pulls",
                state: "open",
                review_requested: true,
                limit: 30
            })
        });
        specs.push({
            slot: "pulls",
            review: false,
            path: "/repos/issues/search" + Http.query({
                type: "pulls",
                state: "open",
                created: true,
                limit: 30
            })
        });
    }
    if (o.issues) {
        specs.push({
            slot: "issues",
            path: "/repos/issues/search" + Http.query({
                type: "issues",
                state: "open",
                assigned: true,
                limit: 30
            })
        });
        specs.push({
            slot: "issues",
            path: "/repos/issues/search" + Http.query({
                type: "issues",
                state: "open",
                created: true,
                limit: 30
            })
        });
        specs.push({
            slot: "issues",
            path: "/repos/issues/search" + Http.query({
                type: "issues",
                state: "open",
                mentioned: true,
                limit: 30
            })
        });
    }
    if (!specs.length)
        return Http.empty(cb, {
            pulls: [],
            issues: []
        });

    var tasks = specs.map(function (spec) {
        return function (done) {
            return Http.request(_req(acct, spec.path), done);
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
            var spec = specs[i];
            (res.data || []).forEach(function (raw) {
                var it = spec.slot === "pulls" ? pull(acct, raw) : issue(acct, raw);
                if (spec.review)
                    it.reviewRequested = true;
                var seen = byId[it.id];
                if (seen) {
                    seen.reviewRequested = seen.reviewRequested || it.reviewRequested;
                    return;
                }
                byId[it.id] = it;
                (spec.slot === "pulls" ? pulls : issues).push(it);
            });
        });

        if (firstError && !pulls.length && !issues.length) {
            cb(firstError);
            return;
        }
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
    });
}

function _repoOf(acct, raw) {
    if (raw.repository && raw.repository.full_name)
        return raw.repository.full_name;
    return C.repoFromIssueUrl(raw.html_url || raw.url);
}

function pull(acct, raw) {
    var pr = raw.pull_request || {};
    var author = (raw.user && raw.user.login) || "";
    var merged = !!pr.merged;
    var draft = !!(raw.draft || pr.draft);
    var assigned = (raw.assignees || []).some(function (a) {
        return a.login === acct.login;
    });
    return C.item({
        avatarUrl: (raw.user && raw.user.avatar_url) || "",
        id: acct.id + ":p:" + raw.id,
        kind: C.KIND.PULL,
        repo: _repoOf(acct, raw),
        title: raw.title,
        url: raw.html_url,
        subjectKey: C.subjectKey(acct.id, raw.html_url),
        tone: Fmt.pullTone(raw.state, draft, merged),
        label: Fmt.pullLabel(raw.state, draft, merged),
        icon: Fmt.pullIcon(raw.state, draft, merged),
        actor: author,
        updatedAt: raw.updated_at || raw.created_at || "",
        number: "#" + raw.number,
        detail: raw.comments ? raw.comments + " comments" : "",
        yours: author === acct.login,
        draft: draft,
        merged: merged,
        assigned: assigned,
        pullNumber: raw.number,
        additions: typeof raw.additions === "number" ? raw.additions : null,
        deletions: typeof raw.deletions === "number" ? raw.deletions : null,
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

function issue(acct, raw) {
    var author = (raw.user && raw.user.login) || "";
    var assigned = (raw.assignees || []).some(function (a) {
        return a.login === acct.login;
    });
    var closed = raw.state === "closed";
    return C.item({
        avatarUrl: (raw.user && raw.user.avatar_url) || "",
        id: acct.id + ":i:" + raw.id,
        kind: C.KIND.ISSUE,
        repo: _repoOf(acct, raw),
        title: raw.title,
        url: raw.html_url,
        subjectKey: C.subjectKey(acct.id, raw.html_url),
        tone: closed ? "muted" : assigned ? "accent" : "positive",
        label: closed ? "closed" : assigned ? "assigned" : "open",
        icon: closed ? "dialog-ok" : "view-task",
        actor: author,
        updatedAt: raw.updated_at || raw.created_at || "",
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

// ── Forgejo Actions ─────────────────────────────────────────────────────────

function pipelines(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    if (o.repos && o.repos.length)
        return _runsFor(acct, o.repos, cb);

    return Http.request(_req(acct, "/user/repos" + Http.query({
        limit: o.count || 6,
        page: 1
    })), function (res) {
        if (!res.ok) {
            cb(res);
            return;
        }
        // Forgejo has no "sort by pushed" on this endpoint, so the ordering is
        // done here rather than pretending the server did it.
        var repos = (res.data || []).slice().sort(function (a, b) {
            return (Date.parse(b.updated_at) || 0) - (Date.parse(a.updated_at) || 0);
        }).slice(0, o.count || 6);
        _runsFor(acct, repos.map(function (r) {
            return r.full_name;
        }), cb);
    });
}

/**
 * Forgejo run status → GitHub's (status, conclusion) pair.
 *
 * ActionTask has no `conclusion` field at all: one `status` string carries
 * both, from the set unknown / waiting / running / success / failure /
 * cancelled / cancelling / skipped / blocked. Reading it as GitHub's `status`
 * and leaving `conclusion` undefined made every finished run — including every
 * failure — render as a muted "unknown", which also kept red pipelines out of
 * the badge entirely.
 *
 * Translating here means Format.js's tone, label and icon tables are reused as
 * they are, exactly as GitLab.runState() does for its own vocabulary.
 */
function runState(status) {
    switch (status) {
    case "success":
        return ["completed", "success"];
    case "failure":
        return ["completed", "failure"];
    case "cancelled":
    case "cancelling":
        return ["completed", "cancelled"];
    case "skipped":
        return ["completed", "skipped"];
    case "running":
        return ["in_progress", ""];
    case "waiting":
    case "blocked":
        return ["queued", ""];
    default:
        // "unknown" — a task the server itself cannot describe.
        return ["completed", ""];
    }
}

function _runsFor(acct, names, cb) {
    if (!names.length)
        return Http.empty(cb, []);
    var tasks = names.map(function (name) {
        return function (done) {
            return Http.request(_req(acct, "/repos/" + name + "/actions/tasks?limit=3"), done);
        };
    });
    return Http.all(tasks, function (results) {
        var runs = [];
        var firstError = null;
        results.forEach(function (res, i) {
            if (!res.ok) {
                // An instance older than Forgejo 1.19, or a repository with
                // Actions disabled, answers 404 — not a failure worth a banner.
                if (!firstError && res.error !== Http.ERR.NOT_FOUND && res.error !== Http.ERR.FORBIDDEN)
                    firstError = res;
                return;
            }
            var list = (res.data && res.data.workflow_runs) || [];
            list.forEach(function (raw) {
                runs.push(task(acct, raw, names[i]));
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

function task(acct, raw, repo) {
    var branch = raw.head_branch || "";
    var st = runState(raw.status);
    return C.item({
        id: acct.id + ":r:" + (raw.id || raw.run_number),
        runId: raw.id || 0,
        kind: C.KIND.RUN,
        repo: repo,
        title: raw.name || raw.display_title || "workflow",
        // ActionTask carries `url`, not `html_url`, and despite the field's
        // own documentation it is the browser link to the run.
        url: raw.url || (webBase(acct) + "/" + repo + "/actions"),
        tone: Fmt.runTone(st[0], st[1]),
        label: Fmt.runLabel(st[0], st[1]),
        icon: Fmt.runIcon(st[0], st[1]),
        updatedAt: raw.updated_at || raw.created_at || "",
        number: raw.run_number ? "#" + raw.run_number : "",
        detail: branch,
        // ActionTask has no actor and no avatar, so "yours" is decided by the
        // branch — the same fallback the GitHub side uses with no login.
        yours: branch === "main" || branch === "master",
        running: st[0] === "in_progress" || st[0] === "queued",
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── mutations ───────────────────────────────────────────────────────────────

function markRead(acct, it, cb) {
    return Http.request(_req(acct, "/notifications/threads/" + it.threadId + "?to-status=read", {
        method: "PATCH",
        conditional: false
    }), cb);
}

function markAllRead(acct, stamp, cb) {
    var q = Http.query({
        "last_read_at": stamp || new Date().toISOString(),
        "to-status": "read"
    });
    return Http.request(_req(acct, "/notifications" + q, {
        method: "PUT",
        conditional: false
    }), cb);
}

function unsubscribe(acct, it, cb) {
    // Forgejo has no thread-subscription endpoint; pinning the thread to
    // "read" is the closest honest equivalent.
    return markRead(acct, it, cb);
}

function rerun(acct, it, cb) {
    return Http.empty(cb, null);
}

// ── profile ─────────────────────────────────────────────────────────────────

function profile(acct, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var tasks = [
        function (done) {
            return Http.request(_req(acct, "/user"), done);
        },
        function (done) {
            return Http.request(_req(acct, "/user/repos?limit=50"), done);
        }
    ];
    return Http.all(tasks, function (results) {
        var me = results[0];
        if (!me.ok) {
            cb(me);
            return;
        }
        var u = me.data || {};
        var repos = (results[1].ok && results[1].data) || [];
        var own = repos.filter(function (r) {
            return !r.fork && r.owner && r.owner.login === u.login;
        });

        cb({
            ok: true,
            status: 200,
            error: "",
            message: "",
            data: {
                profile: C.profile({
                    login: u.login,
                    name: u.full_name,
                    bio: u.description,
                    avatarUrl: u.avatar_url,
                    url: u.html_url || (webBase(acct) + "/" + u.login),
                    location: u.location,
                    website: u.website,
                    createdAt: u.created,
                    followers: u.followers_count,
                    following: u.following_count,
                    starred: u.starred_repos_count,
                    repos: own.length,
                    starsEarned: own.reduce(function (n, r) {
                        return n + (r.stars_count || 0);
                    }, 0),
                    provider: ID
                }),
                calendar: null,
                languages: [],
                repos: own.slice(0, 6).map(function (r) {
                    return r.full_name;
                })
            },
            notModified: false,
            rate: me.rate,
            retryAfter: 0
        });
    });
}

function languages(acct, hint, cb) {
    var names = ((hint && hint.repos) || []).slice(0, 6);
    if (!acct.token || !names.length)
        return Http.empty(cb, []);
    var tasks = names.map(function (name) {
        return function (done) {
            return Http.request(_req(acct, "/repos/" + name + "/languages"), done);
        };
    });
    return Http.all(tasks, function (results) {
        var flat = [];
        results.forEach(function (res) {
            if (!res.ok || !res.data)
                return;
            for (var name in res.data)
                flat.push({
                    name: name,
                    bytes: res.data[name],
                    color: Fmt.languageColor(name)
                });
        });
        Http.empty(cb, C.languages(flat, 6));
    });
}

/**
 * Contribution calendar and hour dial, from one endpoint.
 *
 * Forgejo's heatmap returns `[{ timestamp, contributions }]` at second
 * resolution, which is strictly better than anything GitHub exposes: it fills
 * the heatmap *and* the hour dial from a single request, with no event-feed
 * guessing and no GraphQL.
 */
function activity(acct, cb) {
    if (!acct.token || !acct.login)
        return Http.empty(cb, null);
    return Http.request(_req(acct, "/users/" + encodeURIComponent(acct.login) + "/heatmap"), function (res) {
        if (!res.ok) {
            cb(res);
            return;
        }
        var points = res.data || [];
        var byDay = {};
        var samples = [];
        points.forEach(function (p) {
            var ms = (p.timestamp || 0) * 1000;
            if (!ms)
                return;
            var n = p.contributions || 0;
            samples.push({
                at: ms,
                count: n
            });
            var key = Fmt.localDate(new Date(ms));
            byDay[key] = (byDay[key] || 0) + n;
        });

        var keys = Object.keys(byDay).sort();
        var days = [];
        if (keys.length) {
            var day = new Date(keys[0] + "T12:00:00");
            var end = new Date(keys[keys.length - 1] + "T12:00:00");
            while (day <= end) {
                var k = Fmt.localDate(day);
                days.push({
                    date: k,
                    count: byDay[k] || 0
                });
                day = new Date(day.getTime() + 86400000);
            }
        }

        res.data = {
            calendar: days.length ? C.calendar(days) : null,
            clock: C.clock(samples)
        };
        cb(res);
    });
}

// ── web URLs ────────────────────────────────────────────────────────────────

function notificationsUrl(acct) {
    return webBase(acct) + "/notifications";
}

function repoUrl(acct, fullName) {
    return webBase(acct) + "/" + fullName;
}

function webUrlFor(acct, apiUrl, fallbackRepo) {
    var web = webBase(acct);
    if (!apiUrl)
        return fallbackRepo ? repoUrl(acct, fallbackRepo) : web;
    var prefix = apiBase(acct) + "/repos/";
    var u = String(apiUrl);
    if (u.indexOf(prefix) !== 0)
        return fallbackRepo ? repoUrl(acct, fallbackRepo) : web;
    var parts = u.slice(prefix.length).split("/");
    if (parts.length < 4)
        return web + "/" + parts.slice(0, 2).join("/");
    var kind = parts[2] === "pulls" ? "pulls" : parts[2];
    return web + "/" + parts[0] + "/" + parts[1] + "/" + kind + "/" + parts.slice(3).join("/");
}
