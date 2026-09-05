// Gitpulse — the GitLab provider.
//
// Same interface as GitHub.js, over GitLab's REST v4 API. Works against
// gitlab.com and against any self-hosted instance: only `host` changes.
//
// GitLab's vocabulary differs from GitHub's in three places, and all three are
// translated here rather than leaking upwards:
//   · "todos" are the inbox, and their `action_name` becomes a GitHub reason
//   · merge requests are pull requests
//   · pipeline statuses become a GitHub (status, conclusion) pair, so the
//     shared Format.js tone/label/icon tables are reused unchanged
.pragma library

.import "Http.js" as Http
.import "Format.js" as Fmt
.import "Contract.js" as C

var ID = "gitlab";
var LABEL = "GitLab";
var DEFAULT_HOST = "https://gitlab.com";

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
    // A todo is dismissed, not unsubscribed from; GitLab has no per-thread
    // subscription endpoint that matches, so the row simply does not offer it.
    unsubscribe: false,
    rerun: true,
    copilot: false,
    status: false
};

function webBase(acct) {
    return Http.trimHost(acct && acct.host) || DEFAULT_HOST;
}

function apiBase(acct) {
    return webBase(acct) + "/api/v4";
}

function _req(acct, path, opts) {
    var o = opts || {};
    return {
        url: apiBase(acct) + path,
        method: o.method || "GET",
        token: acct.token,
        scheme: "Bearer",
        // Belt and braces. GitLab reads a personal access token from
        // PRIVATE-TOKEN and an OAuth one from Authorization, and accepts a
        // personal token in either — but "accepts" has moved between versions
        // and self-hosted instances lag. Sending the same value in both is
        // harmless and takes the question off the table for every instance.
        headers: {
            "PRIVATE-TOKEN": acct.token
        },
        body: o.body,
        accept: "application/json",
        conditional: o.conditional,
        cacheKey: o.cacheKey ? acct.id + ":" + o.cacheKey : undefined
    };
}

/**
 * "https://gitlab.com/group/sub/project/-/merge_requests/7" → "group/sub/project".
 * GitLab nests groups arbitrarily deep, so the "/-/" separator is the only
 * reliable boundary between the project path and the rest of the URL.
 */
function repoFromUrl(acct, url) {
    if (!url)
        return "";
    var path = String(url).replace(webBase(acct) + "/", "");
    var cut = path.indexOf("/-/");
    return cut >= 0 ? path.slice(0, cut) : path;
}

// ── identity ────────────────────────────────────────────────────────────────

function viewer(acct, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    return Http.request(_req(acct, "/user"), function (res) {
        if (res.ok && res.data)
            res.data = {
                login: res.data.username,
                name: res.data.name || res.data.username,
                avatarUrl: res.data.avatar_url || "",
                url: res.data.web_url || "",
                id: res.data.id,
                raw: res.data
            };
        cb(res);
    });
}

// ── inbox (todos) ───────────────────────────────────────────────────────────

/**
 * GitLab's todo actions, mapped onto GitHub's notification reasons.
 *
 * The mapping is what makes the badge mean the same thing on both forges:
 * anything that lands on a NEEDS_YOU reason is somebody waiting on you.
 */
var TODO_REASON = {
    assigned: "assign",
    mentioned: "mention",
    directly_addressed: "mention",
    review_requested: "review_requested",
    approval_required: "approval_requested",
    build_failed: "ci_activity",
    unmergeable: "state_change",
    merge_train_removed: "state_change",
    review_submitted: "comment",
    member_access_requested: "member_feature_requested",
    marked: "subscribed",
    okr_checkin_requested: "assign"
};

function inbox(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};

    // GitLab has no "all" flag on todos, and omitting `state` does not mean
    // "both" — the endpoint defaults to pending either way. Done todos are a
    // second list, so "include read" is genuinely a second request. It is off
    // by default, so the common case stays one call.
    var states = o.includeRead ? ["pending", "done"] : ["pending"];
    var tasks = states.map(function (state) {
        return function (done) {
            return Http.request(_req(acct, "/todos" + Http.query({
                state: state,
                per_page: o.perPage || 50
            })), done);
        };
    });

    return Http.all(tasks, function (results) {
        var items = [];
        var firstError = null;
        results.forEach(function (res) {
            if (!res.ok) {
                if (!firstError)
                    firstError = res;
                return;
            }
            (res.data || []).forEach(function (raw) {
                items.push(todo(acct, raw));
            });
        });
        if (firstError && !items.length) {
            cb(firstError);
            return;
        }
        cb({
            ok: true,
            status: 200,
            error: firstError ? firstError.error : "",
            message: firstError ? firstError.message : "",
            data: items,
            // A merged answer cannot claim to be unchanged: `notModified` is
            // what tells the engine it may skip the commit entirely.
            notModified: false,
            rate: results.length ? results[0].rate : null,
            retryAfter: 0
        });
    });
}

function todo(acct, raw) {
    var project = raw.project || raw.group || {};
    var repo = project.path_with_namespace || project.full_path || "";
    var target = raw.target || {};
    var reason = TODO_REASON[raw.action_name] || "subscribed";
    var unread = raw.state !== "done";
    var number = target.iid ? (raw.target_type === "MergeRequest" ? "!" : "#") + target.iid : "";
    return C.item({
        avatarUrl: project.avatar_url || (raw.author && raw.author.avatar_url) || "",
        id: acct.id + ":n:" + raw.id,
        threadId: raw.id,
        kind: C.KIND.NOTIFICATION,
        repo: repo,
        title: target.title || raw.body || "(no title)",
        url: raw.target_url || target.web_url || "",
        subjectKey: C.subjectKey(acct.id, target.web_url || raw.target_url),
        tone: unread ? C.reasonTone(reason) : "muted",
        label: Fmt.reasonLabel(reason),
        icon: Fmt.reasonIcon(reason),
        reason: reason,
        actor: (raw.author && raw.author.username) || "",
        updatedAt: raw.updated_at || raw.created_at || "",
        unread: unread,
        number: number,
        detail: Fmt.humanise(raw.target_type || ""),
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── merge requests and issues ───────────────────────────────────────────────

function work(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    var uid = acct.userId;
    var specs = [];
    if (o.pulls) {
        // GitLab has no "review-requested:@me" search: the reviewer filter is
        // a numeric id, which is why the account carries `userId` from the
        // identity call.
        if (uid)
            specs.push({
                slot: "pulls",
                review: true,
                path: "/merge_requests" + Http.query({
                    state: "opened",
                    scope: "all",
                    reviewer_id: uid,
                    per_page: 30,
                    order_by: "updated_at"
                })
            });
        specs.push({
            slot: "pulls",
            review: false,
            path: "/merge_requests" + Http.query({
                state: "opened",
                scope: "created_by_me",
                per_page: 30,
                order_by: "updated_at"
            })
        });
    }
    if (o.issues) {
        specs.push({
            slot: "issues",
            path: "/issues" + Http.query({
                state: "opened",
                scope: "assigned_to_me",
                per_page: 30,
                order_by: "updated_at"
            })
        });
        specs.push({
            slot: "issues",
            path: "/issues" + Http.query({
                state: "opened",
                scope: "created_by_me",
                per_page: 30,
                order_by: "updated_at"
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
                var it = spec.slot === "pulls" ? mergeRequest(acct, raw) : issue(acct, raw);
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

function mergeRequest(acct, raw) {
    var author = (raw.author && raw.author.username) || "";
    var merged = raw.state === "merged" || !!raw.merged_at;
    var draft = !!(raw.draft || raw.work_in_progress);
    var state = raw.state === "closed" ? "closed" : "open";
    var assigned = (raw.assignees || []).some(function (a) {
        return a.username === acct.login;
    });
    return C.item({
        avatarUrl: (raw.author && raw.author.avatar_url) || "",
        id: acct.id + ":p:" + raw.id,
        kind: C.KIND.PULL,
        repo: repoFromUrl(acct, raw.web_url),
        title: raw.title,
        url: raw.web_url,
        subjectKey: C.subjectKey(acct.id, raw.web_url),
        tone: Fmt.pullTone(state, draft, merged),
        label: Fmt.pullLabel(state, draft, merged),
        icon: Fmt.pullIcon(state, draft, merged),
        actor: author,
        updatedAt: raw.updated_at || raw.created_at || "",
        number: "!" + raw.iid,
        detail: raw.user_notes_count ? raw.user_notes_count + " comments" : (raw.source_branch || ""),
        yours: author === acct.login,
        draft: draft,
        merged: merged,
        assigned: assigned,
        pullNumber: raw.iid,
        additions: raw.stats && typeof raw.stats.additions === "number" ? raw.stats.additions : (typeof raw.additions === "number" ? raw.additions : null),
        deletions: raw.stats && typeof raw.stats.deletions === "number" ? raw.stats.deletions : (typeof raw.deletions === "number" ? raw.deletions : null),
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

function issue(acct, raw) {
    var author = (raw.author && raw.author.username) || "";
    var assigned = (raw.assignees || []).some(function (a) {
        return a.username === acct.login;
    });
    var closed = raw.state === "closed";
    return C.item({
        avatarUrl: (raw.author && raw.author.avatar_url) || "",
        id: acct.id + ":i:" + raw.id,
        kind: C.KIND.ISSUE,
        repo: repoFromUrl(acct, raw.web_url),
        title: raw.title,
        url: raw.web_url,
        subjectKey: C.subjectKey(acct.id, raw.web_url),
        tone: closed ? "muted" : assigned ? "accent" : "positive",
        label: closed ? "closed" : assigned ? "assigned" : "open",
        icon: closed ? "dialog-ok" : "view-task",
        actor: author,
        updatedAt: raw.updated_at || raw.created_at || "",
        number: "#" + raw.iid,
        detail: C.labelNames(raw.labels).join(", "),
        yours: author === acct.login,
        assigned: assigned,
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── pipelines ───────────────────────────────────────────────────────────────

/**
 * GitLab pipeline status → GitHub's (status, conclusion) pair.
 *
 * Translating here means Format.js's tone, label and icon tables — already
 * verified against Breeze — are reused as they are, instead of this file
 * growing a parallel set that drifts.
 */
function runState(status) {
    switch (status) {
    case "success":
        return ["completed", "success"];
    case "failed":
        return ["completed", "failure"];
    case "canceled":
    case "canceling":
        return ["completed", "cancelled"];
    case "skipped":
        return ["completed", "skipped"];
    case "manual":
    case "scheduled":
        return ["completed", "action_required"];
    case "running":
        return ["in_progress", ""];
    default:
        // created, waiting_for_resource, preparing, pending
        return ["queued", ""];
    }
}

function pipelines(acct, opts, cb) {
    if (!acct.token)
        return Http.noToken(cb);
    var o = opts || {};
    if (o.repos && o.repos.length) {
        // An allowlist is written as a path; GitLab's pipeline endpoint takes
        // the URL-encoded path in place of the numeric id.
        return _pipelinesFor(acct, o.repos.map(function (p) {
            return {
                id: encodeURIComponent(p),
                name: p,
                avatar: "",
                branch: ""
            };
        }), cb);
    }

    var q = Http.query({
        membership: true,
        order_by: "last_activity_at",
        sort: "desc",
        per_page: o.count || 6,
        // Without this a user in a large group gets every project they can
        // see, which is the same flood `includeOrgRepos` guards against on
        // GitHub.
        min_access_level: o.includeOrgs ? 20 : 30
    });
    return Http.request(_req(acct, "/projects" + q), function (res) {
        if (!res.ok) {
            cb(res);
            return;
        }
        _pipelinesFor(acct, (res.data || []).map(function (p) {
            return {
                id: p.id,
                name: p.path_with_namespace,
                avatar: p.avatar_url || (p.namespace && p.namespace.avatar_url) || "",
                branch: p.default_branch || ""
            };
        }), cb);
    });
}

function _pipelinesFor(acct, projects, cb) {
    if (!projects.length)
        return Http.empty(cb, []);
    var tasks = projects.map(function (p) {
        return function (done) {
            return Http.request(_req(acct, "/projects/" + p.id + "/pipelines?per_page=3"), done);
        };
    });
    return Http.all(tasks, function (results) {
        var runs = [];
        var firstError = null;
        results.forEach(function (res, i) {
            if (!res.ok) {
                if (!firstError && res.error !== Http.ERR.NOT_FOUND && res.error !== Http.ERR.FORBIDDEN)
                    firstError = res;
                return;
            }
            (res.data || []).forEach(function (raw) {
                runs.push(pipeline(acct, raw, projects[i]));
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

function pipeline(acct, raw, project) {
    var st = runState(raw.status);
    var branch = raw.ref || "";
    return C.item({
        avatarUrl: project.avatar || "",
        id: acct.id + ":r:" + raw.id,
        runId: raw.id,
        kind: C.KIND.RUN,
        repo: project.name,
        title: Fmt.humanise(raw.source || "pipeline"),
        url: raw.web_url || "",
        tone: Fmt.runTone(st[0], st[1]),
        label: Fmt.runLabel(st[0], st[1]),
        icon: Fmt.runIcon(st[0], st[1]),
        updatedAt: raw.updated_at || raw.created_at || "",
        number: "#" + raw.iid,
        detail: branch,
        // The pipeline list carries no author, so "yours" is decided by the
        // branch — the same fallback the GitHub side uses when it has no login.
        yours: !project.branch || branch === project.branch,
        running: st[0] === "in_progress" || st[0] === "queued",
        account: acct.id,
        provider: ID,
        host: webBase(acct),
        raw: raw
    });
}

// ── mutations ───────────────────────────────────────────────────────────────

function markRead(acct, it, cb) {
    return Http.request(_req(acct, "/todos/" + it.threadId + "/mark_as_done", {
        method: "POST",
        conditional: false
    }), cb);
}

function markAllRead(acct, stamp, cb) {
    return Http.request(_req(acct, "/todos/mark_as_done", {
        method: "POST",
        conditional: false
    }), cb);
}

function unsubscribe(acct, it, cb) {
    return markRead(acct, it, cb);
}

function rerun(acct, it, cb) {
    var project = encodeURIComponent(it.repo);
    return Http.request(_req(acct, "/projects/" + project + "/pipelines/" + it.runId + "/retry", {
        method: "POST",
        conditional: false
    }), cb);
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
            return Http.request(_req(acct, "/projects" + Http.query({
                owned: true,
                order_by: "last_activity_at",
                sort: "desc",
                per_page: 20
            })), done);
        }
    ];

    return Http.all(tasks, function (results) {
        var me = results[0];
        if (!me.ok) {
            cb(me);
            return;
        }
        var u = me.data || {};
        var projects = (results[1].ok && results[1].data) || [];
        var stars = projects.reduce(function (n, p) {
            return n + (p.star_count || 0);
        }, 0);

        cb({
            ok: true,
            status: 200,
            error: "",
            message: "",
            data: {
                profile: C.profile({
                    login: u.username,
                    name: u.name,
                    bio: u.bio,
                    avatarUrl: u.avatar_url,
                    url: u.web_url,
                    company: u.organization,
                    location: u.location,
                    website: u.website_url,
                    createdAt: u.created_at,
                    followers: u.followers,
                    following: u.following,
                    repos: projects.length,
                    starsEarned: stars,
                    provider: ID
                }),
                // Filled in by activity() — GitLab has no single call that
                // returns identity and a contribution calendar together.
                calendar: null,
                languages: [],
                repos: projects.map(function (p) {
                    return p.id;
                })
            },
            notModified: false,
            rate: me.rate,
            retryAfter: 0
        });
    });
}

/**
 * Language mix, one call per project.
 *
 * GitLab reports percentages per project rather than bytes across an account,
 * so the shares are averaged over the user's most recently active projects.
 * Capped at six: this runs on the half-hourly timer and each project is a
 * request.
 */
var LANG_PROJECTS = 6;

function languages(acct, hint, cb) {
    var ids = ((hint && hint.repos) || []).slice(0, LANG_PROJECTS);
    if (!acct.token || !ids.length)
        return Http.empty(cb, []);
    var tasks = ids.map(function (id) {
        return function (done) {
            return Http.request(_req(acct, "/projects/" + id + "/languages"), done);
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
 * Contribution calendar and hour dial.
 *
 * GitLab's own profile page is drawn from `/users/:name/calendar.json`, which
 * is a year of date→count and exactly what the heatmap wants. It is a web
 * endpoint rather than a documented API one, so a refusal is not an error:
 * the event feed below covers both the dial and a shorter calendar.
 */
function activity(acct, cb) {
    if (!acct.token || !acct.login)
        return Http.empty(cb, null);

    var tasks = [
        function (done) {
            return Http.request({
                url: webBase(acct) + "/users/" + encodeURIComponent(acct.login) + "/calendar.json",
                token: acct.token,
                scheme: "Bearer",
                headers: {
                    "PRIVATE-TOKEN": acct.token
                },
                accept: "application/json",
                cacheKey: acct.id + ":calendar"
            }, done);
        },
        function (done) {
            return Http.request(_req(acct, "/events" + Http.query({
                per_page: 100
            })), done);
        }
    ];

    return Http.all(tasks, function (results) {
        var days = [];
        if (results[0].ok && results[0].data) {
            for (var date in results[0].data)
                days.push({
                    date: date,
                    count: results[0].data[date]
                });
        }

        var samples = [];
        if (results[1].ok && results[1].data) {
            (results[1].data || []).forEach(function (e) {
                var n = e.action_name === "pushed to" || e.action_name === "pushed new" ? Math.max(1, (e.push_data && e.push_data.commit_count) || 1) : 1;
                samples.push({
                    at: e.created_at,
                    count: n
                });
            });
            // No calendar.json (private profile, or an instance that does not
            // serve it) — derive a shorter one from the events instead of
            // showing nothing.
            if (!days.length)
                days = _daysFrom(samples);
        }

        Http.empty(cb, {
            calendar: days.length ? C.calendar(days) : null,
            clock: C.clock(samples)
        });
    });
}

function _daysFrom(samples) {
    var byDay = {};
    samples.forEach(function (s) {
        var t = Date.parse(s.at);
        if (isNaN(t))
            return;
        var key = Fmt.localDate(new Date(t));
        byDay[key] = (byDay[key] || 0) + s.count;
    });
    // Fill the gaps: a calendar with holes in it draws a broken grid.
    var keys = Object.keys(byDay).sort();
    if (!keys.length)
        return [];
    var out = [];
    var day = new Date(keys[0] + "T12:00:00");
    var end = new Date(keys[keys.length - 1] + "T12:00:00");
    while (day <= end) {
        var k = Fmt.localDate(day);
        out.push({
            date: k,
            count: byDay[k] || 0
        });
        day = new Date(day.getTime() + 86400000);
    }
    return out;
}

// ── web URLs ────────────────────────────────────────────────────────────────

function notificationsUrl(acct) {
    return webBase(acct) + "/dashboard/todos";
}

function repoUrl(acct, fullName) {
    return webBase(acct) + "/" + fullName;
}
