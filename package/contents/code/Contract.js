// Gitpulse — normalisation.
//
// Five very different GitHub payloads collapse into one item shape here, so
// the QML rows, the badge arithmetic and the two frontends never branch on
// which endpoint something came from.
//
//   { id, kind, repo, title, url, subjectKey, tone, label, icon,
//     reason, actor, updatedAt, unread, number, detail, yours, raw }
//
// `tone` is the only colour vocabulary the UI knows: positive, negative,
// neutral, accent, muted. It maps to Kirigami.Theme roles in one place.
.pragma library

.import "Format.js" as Fmt
.import "GitHub.js" as GH

/**
 * Notification reasons that mean somebody is waiting on this user. Everything
 * else is still shown, but it never reaches the tray badge — a badge that
 * counts "subscribed" threads is a badge people learn to ignore.
 */
var NEEDS_YOU_REASONS = {
    review_requested: true,
    approval_requested: true,
    mention: true,
    team_mention: true,
    assign: true,
    security_alert: true
};

var KIND = {
    NOTIFICATION: "notification",
    RUN: "run",
    PULL: "pull_request",
    ISSUE: "issue"
};

// ── notifications ───────────────────────────────────────────────────────────

function notification(raw) {
    var subject = raw.subject || {};
    var repo = (raw.repository && raw.repository.full_name) || "";
    var url = GH.webUrlFor(subject.url, repo);
    return {
        // The owner's picture is what turns a wall of text into something
        // scannable — the same trick GitHub's own inbox uses.
        avatarUrl: (raw.repository && raw.repository.owner && raw.repository.owner.avatar_url) || "",
        id: "n:" + raw.id,
        threadId: raw.id,
        kind: KIND.NOTIFICATION,
        repo: repo,
        title: subject.title || "(no title)",
        url: url,
        subjectKey: subjectKey(subject.url),
        tone: raw.unread ? reasonTone(raw.reason) : "muted",
        label: Fmt.reasonLabel(raw.reason),
        icon: Fmt.reasonIcon(raw.reason),
        reason: raw.reason || "",
        actor: "",
        updatedAt: raw.updated_at || "",
        unread: !!raw.unread,
        number: numberFrom(subject.url),
        detail: Fmt.humanise(subject.type || ""),
        yours: false,
        raw: raw
    };
}

function reasonTone(reason) {
    if (reason === "security_alert" || reason === "security_advisory_credit")
        return "negative";
    if (reason === "ci_activity")
        return "neutral";
    if (NEEDS_YOU_REASONS[reason])
        return "accent";
    return "muted";
}

// ── Actions runs ────────────────────────────────────────────────────────────

function run(raw, viewerLogin) {
    var repo = (raw.repository && raw.repository.full_name) || raw._repo || "";
    var actor = (raw.actor && raw.actor.login) || (raw.triggering_actor && raw.triggering_actor.login) || "";
    // A run triggered by a pull request carries it here, which lets the UI
    // offer "open the pull request" instead of only the run log.
    var prs = raw.pull_requests || [];
    return {
        pullNumber: prs.length ? prs[0].number : 0,
        avatarUrl: (raw.actor && raw.actor.avatar_url) || (raw.repository && raw.repository.owner && raw.repository.owner.avatar_url) || "",
        id: "r:" + raw.id,
        runId: raw.id,
        kind: KIND.RUN,
        repo: repo,
        title: raw.name || raw.display_title || "workflow",
        url: raw.html_url || GH.runUrl(repo, raw.id),
        subjectKey: "",
        tone: Fmt.runTone(raw.status, raw.conclusion),
        label: Fmt.runLabel(raw.status, raw.conclusion),
        icon: Fmt.runIcon(raw.status, raw.conclusion),
        reason: "",
        actor: actor,
        updatedAt: raw.updated_at || raw.created_at || "",
        unread: false,
        number: raw.run_number ? "#" + raw.run_number : "",
        detail: raw.head_branch || "",
        // "Yours" decides whether a red pipeline reaches the badge. A failure
        // on a colleague's branch is information; a failure on yours is a task.
        yours: !viewerLogin || actor === viewerLogin || raw.head_branch === "main" || raw.head_branch === "master",
        running: raw.status === "in_progress" || raw.status === "queued" || raw.status === "pending",
        raw: raw
    };
}

// ── search results (pull requests and issues) ───────────────────────────────

function searchItem(raw, viewerLogin) {
    var isPull = !!raw.pull_request;
    var repo = repoFromIssueUrl(raw.repository_url || raw.html_url);
    var merged = isPull && !!raw.pull_request.merged_at;
    var draft = !!raw.draft;
    var author = (raw.user && raw.user.login) || "";
    var assigned = (raw.assignees || []).some(function (a) {
        return a.login === viewerLogin;
    });

    if (isPull) {
        return {
            avatarUrl: (raw.user && raw.user.avatar_url) || "",
            id: "p:" + raw.id,
            kind: KIND.PULL,
            repo: repo,
            title: raw.title || "",
            url: raw.html_url,
            subjectKey: subjectKey(raw.pull_request.url || raw.url),
            tone: Fmt.pullTone(raw.state, draft, merged),
            label: Fmt.pullLabel(raw.state, draft, merged),
            icon: Fmt.pullIcon(raw.state, draft, merged),
            reason: "",
            actor: author,
            updatedAt: raw.updated_at || "",
            unread: false,
            number: "#" + raw.number,
            detail: (raw.comments ? raw.comments + " comments" : ""),
            yours: author === viewerLogin,
            draft: draft,
            merged: merged,
            assigned: assigned,
            // Filled in by the caller: the search query that produced this item
            // is the only reliable signal that a review was requested of you.
            reviewRequested: false,
            raw: raw
        };
    }

    return {
        avatarUrl: (raw.user && raw.user.avatar_url) || "",
        id: "i:" + raw.id,
        kind: KIND.ISSUE,
        repo: repo,
        title: raw.title || "",
        url: raw.html_url,
        subjectKey: subjectKey(raw.url),
        tone: raw.state === "closed" ? "muted" : assigned ? "accent" : "positive",
        label: raw.state === "closed" ? "closed" : assigned ? "assigned" : "open",
        icon: raw.state === "closed" ? "dialog-ok" : "view-task",
        reason: "",
        actor: author,
        updatedAt: raw.updated_at || "",
        unread: false,
        number: "#" + raw.number,
        detail: labelNames(raw.labels).join(", "),
        yours: author === viewerLogin,
        assigned: assigned,
        raw: raw
    };
}

function labelNames(labels) {
    return (labels || []).map(function (l) {
        return typeof l === "string" ? l : l.name;
    }).filter(Boolean);
}

function repoFromIssueUrl(url) {
    if (!url)
        return "";
    var m = String(url).match(/repos\/([^/]+\/[^/]+)/);
    if (m)
        return m[1];
    m = String(url).match(/github\.com\/([^/]+\/[^/]+)/);
    return m ? m[1] : "";
}

function numberFrom(url) {
    if (!url)
        return "";
    var m = String(url).match(/\/(\d+)$/);
    return m ? "#" + m[1] : "";
}

/**
 * A stable key for "the thing this item is about", so a ci_activity
 * notification and the failed run behind it, or a review_requested
 * notification and the PR itself, can be recognised as one event.
 */
function subjectKey(apiUrl) {
    if (!apiUrl)
        return "";
    return String(apiUrl).replace(/^https:\/\/api\.github\.com\/repos\//, "").replace(/\/pulls\//, "/issues/");
}

// ── badge arithmetic ────────────────────────────────────────────────────────

function needsYou(item) {
    if (!item)
        return false;
    switch (item.kind) {
    case KIND.NOTIFICATION:
        return item.unread && !!NEEDS_YOU_REASONS[item.reason];
    case KIND.RUN:
        return item.tone === "negative" && item.yours;
    case KIND.PULL:
        return !!item.reviewRequested;
    default:
        // Assigned issues are tracked but never inflate the badge: the badge
        // means "someone is blocked on you", and an open issue is not that.
        return false;
    }
}

/**
 * Cross-tab de-duplication.
 *
 * Marks every item with `counts`, false when a different tab already claims
 * the same subject. The inbox wins, because that is where the action lives.
 * Items are mutated in place and returned for convenience.
 */
function dedupe(sections) {
    var claimed = {};
    var order = ["inbox", "pulls", "issues", "actions"];

    order.forEach(function (name) {
        (sections[name] || []).forEach(function (item) {
            var counted = needsYou(item);
            if (!counted) {
                item.counts = false;
                item.duplicate = false;
                return;
            }
            var key = item.subjectKey;
            if (key && claimed[key]) {
                item.counts = false;
                item.duplicate = true;
            } else {
                item.counts = true;
                item.duplicate = false;
                if (key)
                    claimed[key] = item.kind;
            }
        });
    });
    return sections;
}

function countNeeds(items) {
    return (items || []).filter(function (i) {
        return i.counts;
    }).length;
}

function countUnread(items) {
    return (items || []).filter(function (i) {
        return i.unread;
    }).length;
}

/** One number for the tray, plus the breakdown the tooltip shows. */
function badge(sections) {
    dedupe(sections);
    var perTab = {
        inbox: countNeeds(sections.inbox),
        actions: countNeeds(sections.actions),
        pulls: countNeeds(sections.pulls),
        issues: countNeeds(sections.issues)
    };
    var total = perTab.inbox + perTab.actions + perTab.pulls + perTab.issues;
    var tracked = (sections.inbox || []).length + (sections.actions || []).length + (sections.pulls || []).length + (sections.issues || []).length;
    return {
        needsYou: total,
        unread: countUnread(sections.inbox),
        tracked: tracked,
        perTab: perTab,
        failing: (sections.actions || []).filter(function (r) {
            return r.tone === "negative";
        }).length,
        toReview: (sections.pulls || []).filter(function (p) {
            return p.reviewRequested;
        }).length,
        assigned: (sections.issues || []).filter(function (i) {
            return i.assigned;
        }).length
    };
}

// ── sorting ─────────────────────────────────────────────────────────────────

function byUpdatedDesc(a, b) {
    return (Date.parse(b.updatedAt) || 0) - (Date.parse(a.updatedAt) || 0);
}

/** Needs-you first, then newest. Actions instead sorts by severity. */
function sortItems(items, kind) {
    var out = (items || []).slice();
    if (kind === "actions") {
        var weight = {
            negative: 0,
            accent: 1,
            neutral: 2,
            muted: 3,
            positive: 4
        };
        out.sort(function (a, b) {
            var d = (weight[a.tone] === undefined ? 5 : weight[a.tone]) - (weight[b.tone] === undefined ? 5 : weight[b.tone]);
            return d !== 0 ? d : byUpdatedDesc(a, b);
        });
        return out;
    }
    out.sort(function (a, b) {
        var d = (needsYou(b) ? 1 : 0) - (needsYou(a) ? 1 : 0);
        return d !== 0 ? d : byUpdatedDesc(a, b);
    });
    return out;
}

/**
 * The quick-filter chips. One implementation, used both to filter the list and
 * to label the chips, so a chip can never advertise a count it does not yield.
 */
function applyChip(items, chip) {
    var list = items || [];
    switch (chip) {
    case "needs":
        return list.filter(needsYou);
    case "mention":
        return list.filter(function (i) {
            return i.reason === "mention" || i.reason === "team_mention";
        });
    case "unread":
        return list.filter(function (i) {
            return i.unread;
        });
    case "failed":
        return list.filter(function (i) {
            return i.tone === "negative";
        });
    case "active":
        return list.filter(function (i) {
            return i.running;
        });
    case "review":
        return list.filter(function (i) {
            return i.reviewRequested;
        });
    case "mine":
        return list.filter(function (i) {
            return i.yours;
        });
    case "assigned":
        return list.filter(function (i) {
            return i.assigned;
        });
    default:
        return list.slice();
    }
}

function search(items, query) {
    var q = String(query || "").trim().toLowerCase();
    if (!q)
        return items || [];
    return (items || []).filter(function (i) {
        return (i.title + " " + i.repo + " " + (i.detail || "")).toLowerCase().indexOf(q) >= 0;
    });
}

function groupByRepo(items) {
    var order = [];
    var map = {};
    (items || []).forEach(function (i) {
        if (!map[i.repo]) {
            map[i.repo] = [];
            order.push(i.repo);
        }
        map[i.repo].push(i);
    });
    return order.map(function (repo) {
        return {
            repo: repo,
            items: map[repo]
        };
    });
}

// ── profile ─────────────────────────────────────────────────────────────────

/** Flattens the GraphQL user node into what the Profile tab actually draws. */
function profile(userNode) {
    if (!userNode)
        return null;
    var c = userNode.contributionsCollection || {};
    var repos = (userNode.repositories && userNode.repositories.nodes) || [];
    var stars = repos.reduce(function (n, r) {
        return n + (r.stargazerCount || 0);
    }, 0);
    return {
        login: userNode.login || "",
        name: userNode.name || userNode.login || "",
        bio: userNode.bio || "",
        avatarUrl: userNode.avatarUrl || "",
        url: userNode.url || "",
        company: userNode.company || "",
        location: userNode.location || "",
        website: userNode.websiteUrl || "",
        createdAt: userNode.createdAt || "",
        followers: count(userNode.followers),
        following: count(userNode.following),
        gists: count(userNode.gists),
        starred: count(userNode.starredRepositories),
        orgs: count(userNode.organizations),
        sponsors: count(userNode.sponsors),
        repos: (userNode.repositories && userNode.repositories.totalCount) || repos.length,
        starsEarned: stars,
        commits: c.totalCommitContributions || 0,
        pulls: c.totalPullRequestContributions || 0,
        issues: c.totalIssueContributions || 0,
        reviews: c.totalPullRequestReviewContributions || 0,
        privateContributions: c.restrictedContributionsCount || 0
    };
}

function count(node) {
    return (node && node.totalCount) || 0;
}

/**
 * Contribution calendar → a fixed 7-row grid plus intensity levels.
 *
 * Levels are cut at the 90th percentile of active days rather than the maximum
 * so one 200-commit merge day does not flatten the rest of the year to level 1.
 */
function calendar(contributionsCollection) {
    var cal = contributionsCollection && contributionsCollection.contributionCalendar;
    if (!cal || !cal.weeks)
        return null;

    var counts = [];
    cal.weeks.forEach(function (w) {
        (w.contributionDays || []).forEach(function (d) {
            if (d.contributionCount > 0)
                counts.push(d.contributionCount);
        });
    });
    counts.sort(function (a, b) {
        return a - b;
    });
    var ceiling = counts.length ? counts[Math.floor(counts.length * 0.9)] || counts[counts.length - 1] : 1;

    // Flat, chronological — the grid is for the eye, this is for the maths.
    var flat = [];
    var weeks = cal.weeks.map(function (w) {
        var days = new Array(7);
        (w.contributionDays || []).forEach(function (d) {
            var cell = {
                date: d.date,
                count: d.contributionCount,
                level: level(d.contributionCount, ceiling)
            };
            days[d.weekday] = cell;
            flat.push(cell);
        });
        for (var i = 0; i < 7; i++) {
            if (!days[i])
                days[i] = null; // padding at the start/end of the range
        }
        return days;
    });

    var total = cal.totalContributions || 0;
    return {
        total: total,
        weeks: weeks,
        days: flat,
        ceiling: ceiling,
        busiest: counts.length ? counts[counts.length - 1] : 0,
        busiestDate: busiestDate(flat),
        activeDays: counts.length,
        average: flat.length ? total / flat.length : 0,
        streak: longestStreak(cal.weeks),
        current: currentStreak(flat),
        recent: flat.slice(-30)
    };
}

function busiestDate(flat) {
    var best = null;
    flat.forEach(function (d) {
        if (!best || d.count > best.count)
            best = d;
    });
    return best ? best.date : "";
}

/**
 * Days in a row up to now.
 *
 * Today counts as neutral rather than as a break: the day is not over, and a
 * streak that resets at midnight and un-resets after your first commit is a
 * number nobody trusts.
 */
function currentStreak(flat) {
    if (!flat.length)
        return 0;
    var i = flat.length - 1;
    if (flat[i].count === 0)
        i--;
    var n = 0;
    for (; i >= 0; i--) {
        if (flat[i].count <= 0)
            break;
        n++;
    }
    return n;
}

/**
 * Time-of-day distribution from the public events feed.
 *
 * Buckets are in the viewer's own timezone, which is the only one that answers
 * the question being asked ("when do I work?").
 */
var RHYTHM_BUCKETS = [
    {
        id: "morning",
        from: 6,
        to: 11
    },
    {
        id: "day",
        from: 12,
        to: 14
    },
    {
        id: "afternoon",
        from: 15,
        to: 17
    },
    {
        id: "evening",
        from: 18,
        to: 23
    },
    {
        id: "night",
        from: 0,
        to: 5
    }
];

function rhythm(events) {
    var counts = {};
    RHYTHM_BUCKETS.forEach(function (b) {
        counts[b.id] = 0;
    });

    var total = 0;
    (events || []).forEach(function (e) {
        var t = Date.parse(e.created_at);
        if (isNaN(t))
            return;
        var h = new Date(t).getHours();
        for (var i = 0; i < RHYTHM_BUCKETS.length; i++) {
            var b = RHYTHM_BUCKETS[i];
            if (h >= b.from && h <= b.to) {
                counts[b.id]++;
                total++;
                break;
            }
        }
    });
    if (!total)
        return [];

    return RHYTHM_BUCKETS.map(function (b) {
        return {
            name: b.id,
            count: counts[b.id],
            share: counts[b.id] / total * 100
        };
    }).sort(function (a, b) {
        return b.count - a.count;
    });
}

function level(count, ceiling) {
    if (!count)
        return 0;
    if (!ceiling || count >= ceiling)
        return 4;
    return Math.max(1, Math.min(4, Math.ceil(count / ceiling * 4)));
}

function longestStreak(weeks) {
    var best = 0;
    var cur = 0;
    weeks.forEach(function (w) {
        (w.contributionDays || []).forEach(function (d) {
            if (d.contributionCount > 0) {
                cur++;
                if (cur > best)
                    best = cur;
            } else {
                cur = 0;
            }
        });
    });
    return best;
}

/**
 * Language mix by bytes across the user's own non-fork repositories.
 * Colours come from the API, so the bar matches what GitHub itself shows
 * without this file carrying a hard-coded language palette.
 */
function languages(userNode, topN) {
    var repos = (userNode && userNode.repositories && userNode.repositories.nodes) || [];
    var totals = {};
    var colours = {};
    var grand = 0;

    repos.forEach(function (r) {
        var edges = (r.languages && r.languages.edges) || [];
        edges.forEach(function (e) {
            if (!e || !e.node)
                return;
            var n = e.node.name;
            totals[n] = (totals[n] || 0) + (e.size || 0);
            colours[n] = e.node.color || "";
            grand += e.size || 0;
        });
    });
    if (!grand)
        return [];

    var list = Object.keys(totals).map(function (n) {
        return {
            name: n,
            bytes: totals[n],
            color: colours[n],
            share: totals[n] / grand * 100
        };
    });
    list.sort(function (a, b) {
        return b.bytes - a.bytes;
    });

    var top = list.slice(0, topN || 6);
    var rest = list.slice(topN || 6).reduce(function (n, l) {
        return n + l.share;
    }, 0);
    if (rest > 0.5)
        top.push({
            name: "Other",
            bytes: 0,
            color: "",
            share: rest
        });
    return top;
}

// ── service status ──────────────────────────────────────────────────────────

function components(summary, onlyShowcase) {
    var list = (summary && summary.components) || [];
    return list.filter(function (c) {
        return !c.group && (!onlyShowcase || c.showcase);
    }).map(function (c) {
        return {
            id: c.id,
            name: c.name,
            description: c.description || "",
            status: c.status,
            tone: Fmt.componentTone(c.status),
            updatedAt: c.updated_at || ""
        };
    });
}

function copilotComponents(summary) {
    return components(summary, false).filter(function (c) {
        return c.name.toLowerCase().indexOf("copilot") >= 0;
    });
}

/**
 * A 90-day strip per component, derived from the public incident feed.
 *
 * githubstatus.com does not publish the per-component uptime series behind the
 * bars on its own site, so this is explicitly "days with a recorded incident",
 * not GitHub's uptime percentage. The UI labels it as such — a number that
 * looks like an SLA but is not one would be worse than no number.
 */
function incidentStrip(incidents, componentId, days, now) {
    var span = days || 90;
    var end = now === undefined ? Date.now() : now;
    var DAY = 86400000;

    // Buckets are UTC calendar days, not rolling 24-hour windows offset from
    // whatever time it happens to be: a "90-day strip" means 90 dates. Rolling
    // windows also smear a two-hour incident across two cells, which reads as
    // twice the outage that actually happened.
    var d0 = new Date(end);
    var todayStart = Date.UTC(d0.getUTCFullYear(), d0.getUTCMonth(), d0.getUTCDate());

    var strip = new Array(span);
    var i;
    for (i = 0; i < span; i++) {
        var start = todayStart - (span - 1 - i) * DAY;
        strip[i] = {
            offset: span - 1 - i,
            start: start,
            date: Fmt.isoDate(new Date(start)),
            tone: "positive",
            impact: ""
        };
    }

    var rank = {
        minor: 1,
        major: 2,
        critical: 3
    };

    (incidents || []).forEach(function (inc) {
        var hits = (inc.components || []).some(function (c) {
            return c.id === componentId;
        });
        if (!hits)
            return;
        var from = Date.parse(inc.created_at);
        if (isNaN(from))
            return;
        // An unresolved incident is still running, so it colours every day up
        // to and including today.
        var to = Date.parse(inc.resolved_at || "");
        if (isNaN(to))
            to = end;

        for (var d = 0; d < span; d++) {
            var cell = strip[d];
            if (from >= cell.start + DAY || to < cell.start)
                continue;
            if (!cell.impact || (rank[inc.impact] || 0) > (rank[cell.impact] || 0)) {
                cell.impact = inc.impact;
                cell.tone = Fmt.impactTone(inc.impact);
            }
        }
    });

    return strip;
}

function stripSummary(strip) {
    var bad = strip.filter(function (d) {
        return d.impact;
    }).length;
    return {
        days: strip.length,
        incidentDays: bad,
        cleanDays: strip.length - bad
    };
}

function activeIncidents(incidents) {
    return (incidents || []).filter(function (i) {
        return i.status !== "resolved" && i.status !== "postmortem";
    });
}
