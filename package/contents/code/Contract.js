// Gitpulse — the shared vocabulary.
//
// Three forges, a dozen very different payloads, one item shape. Each provider
// module (GitHub.js, GitLab.js, Forgejo.js) turns its own JSON into `item()`
// below; everything above this file — the QML rows, the badge arithmetic and
// both frontends — never branches on which forge something came from.
//
//   { id, kind, repo, title, url, subjectKey, tone, label, icon,
//     reason, actor, updatedAt, unread, number, detail, yours,
//     account, provider, raw }
//
// `tone` is the only colour vocabulary the UI knows: positive, negative,
// neutral, accent, muted. It maps to a real colour in exactly one place per
// frontend (Tones.qml and hyprland/Theme.qml).
.pragma library

.import "Format.js" as Fmt

/**
 * Notification reasons that mean somebody is waiting on this user. Everything
 * else is still shown, but it never reaches the tray badge — a badge that
 * counts "subscribed" threads is a badge people learn to ignore.
 *
 * GitLab and Forgejo do not send GitHub's `reason` field; their providers map
 * their own signals onto these same names rather than inventing new ones.
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

/**
 * The canonical item constructor.
 *
 * Every provider funnels through here, which is what stops the three of them
 * drifting apart field by field: a row that reads `item.draft` gets `false`
 * rather than `undefined` no matter which forge produced it.
 */
function item(spec) {
    var s = spec || {};
    return {
        id: s.id || "",
        kind: s.kind || KIND.NOTIFICATION,
        repo: s.repo || "",
        title: s.title || "(no title)",
        url: s.url || "",
        subjectKey: s.subjectKey || "",
        tone: s.tone || "muted",
        label: s.label || "",
        icon: s.icon || "mail-message",
        reason: s.reason || "",
        actor: s.actor || "",
        avatarUrl: s.avatarUrl || "",
        updatedAt: s.updatedAt || "",
        unread: !!s.unread,
        number: s.number || "",
        detail: s.detail || "",
        yours: !!s.yours,
        // Pull-request and issue extras. Present on every item so a filter can
        // read them unconditionally.
        draft: !!s.draft,
        merged: !!s.merged,
        assigned: !!s.assigned,
        reviewRequested: !!s.reviewRequested,
        running: !!s.running,
        // Mutation handles: only the provider that made the item knows what
        // these mean.
        threadId: s.threadId || "",
        runId: s.runId || 0,
        pullNumber: s.pullNumber || 0,
        additions: s.additions !== undefined && s.additions !== null ? Number(s.additions) : null,
        deletions: s.deletions !== undefined && s.deletions !== null ? Number(s.deletions) : null,
        // Which configured account this came from, so a two-forge inbox can be
        // grouped, filtered and acted on per account.
        account: s.account || "",
        provider: s.provider || "github",
        host: s.host || "",
        raw: s.raw || null
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

// ── URL and id helpers, shared by the providers ─────────────────────────────

function repoFromIssueUrl(url) {
    if (!url)
        return "";
    var m = String(url).match(/repos\/([^/]+\/[^/]+)/);
    if (m)
        return m[1];
    m = String(url).match(/\/([^/]+\/[^/]+)\/(?:issues|pull|pulls|-)\//);
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
 * notification and the pull request itself, can be recognised as one event.
 *
 * Scoped by account: two forges can both have an `owner/repo/issues/1`, and
 * de-duplicating across them would silently hide one of the two.
 */
function subjectKey(accountId, apiUrl) {
    if (!apiUrl)
        return "";
    var path = String(apiUrl).replace(/^https?:\/\/[^/]+\//, "").replace(/^api\/v[0-9]+\//, "").replace(/^repos\//, "").replace(/\/(?:pulls|merge_requests)\//, "/issues/");
    return (accountId || "") + "|" + path;
}

function labelNames(labels) {
    return (labels || []).map(function (l) {
        return typeof l === "string" ? l : (l && (l.name || l.title)) || "";
    }).filter(Boolean);
}

// ── badge arithmetic ────────────────────────────────────────────────────────

function needsYou(it) {
    if (!it)
        return false;
    switch (it.kind) {
    case KIND.NOTIFICATION:
        return it.unread && !!NEEDS_YOU_REASONS[it.reason];
    case KIND.RUN:
        return it.tone === "negative" && it.yours;
    case KIND.PULL:
        return !!it.reviewRequested;
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
        (sections[name] || []).forEach(function (it) {
            var counted = needsYou(it);
            if (!counted) {
                it.counts = false;
                it.duplicate = false;
                return;
            }
            var key = it.subjectKey;
            if (key && claimed[key]) {
                it.counts = false;
                it.duplicate = true;
            } else {
                it.counts = true;
                it.duplicate = false;
                if (key)
                    claimed[key] = it.kind;
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

/**
 * The profile shape every provider fills in.
 *
 * Not every forge has every figure — Forgejo has no review count, GitLab has
 * no "stars earned" across your own repositories — so a missing number is
 * `null`, which the UI renders as "—" rather than as a confident zero.
 */
function profile(spec) {
    var s = spec || {};
    function num(v) {
        return v === undefined || v === null ? null : v;
    }
    return {
        login: s.login || "",
        name: s.name || s.login || "",
        bio: s.bio || "",
        avatarUrl: s.avatarUrl || "",
        url: s.url || "",
        company: s.company || "",
        location: s.location || "",
        website: s.website || "",
        createdAt: s.createdAt || "",
        followers: num(s.followers),
        following: num(s.following),
        gists: num(s.gists),
        starred: num(s.starred),
        orgs: num(s.orgs),
        sponsors: num(s.sponsors),
        repos: num(s.repos),
        starsEarned: num(s.starsEarned),
        commits: num(s.commits),
        pulls: num(s.pulls),
        issues: num(s.issues),
        reviews: num(s.reviews),
        privateContributions: s.privateContributions || 0,
        provider: s.provider || "github"
    };
}

/**
 * Day counts → a fixed 7-row grid plus intensity levels.
 *
 * Takes the provider-neutral `[{ date: "YYYY-MM-DD", count: n }]` list, sorted
 * or not, so GitHub's GraphQL calendar and Forgejo's heatmap endpoint reach the
 * same grid without the UI knowing the difference.
 *
 * Levels are cut at the 90th percentile of active days rather than the maximum
 * so one 200-commit merge day does not flatten the rest of the year to level 1.
 */
function calendar(days, totalOverride) {
    var list = (days || []).filter(function (d) {
        return d && d.date;
    });
    if (!list.length)
        return null;

    list = list.slice().sort(function (a, b) {
        return a.date < b.date ? -1 : a.date > b.date ? 1 : 0;
    });

    var counts = [];
    list.forEach(function (d) {
        if (d.count > 0)
            counts.push(d.count);
    });
    counts.sort(function (a, b) {
        return a - b;
    });
    var ceiling = counts.length ? counts[Math.floor(counts.length * 0.9)] || counts[counts.length - 1] : 1;

    // Pad to whole weeks so the grid has no ragged column: the first cell of
    // the range rarely lands on a Sunday.
    var flat = list.map(function (d) {
        return {
            date: d.date,
            count: d.count || 0,
            level: level(d.count || 0, ceiling)
        };
    });

    var weeks = [];
    var week = new Array(7);
    var filled = false;
    flat.forEach(function (cell) {
        var wd = new Date(cell.date + "T00:00:00Z").getUTCDay();
        if (filled && wd === 0) {
            weeks.push(week);
            week = new Array(7);
        }
        week[wd] = cell;
        filled = true;
    });
    if (filled)
        weeks.push(week);
    weeks.forEach(function (w) {
        for (var i = 0; i < 7; i++) {
            if (!w[i])
                w[i] = null; // padding at the start/end of the range
        }
    });

    var total = totalOverride === undefined || totalOverride === null ? flat.reduce(function (n, d) {
        return n + d.count;
    }, 0) : totalOverride;

    return {
        total: total,
        weeks: weeks,
        days: flat,
        ceiling: ceiling,
        busiest: counts.length ? counts[counts.length - 1] : 0,
        busiestDate: busiestDate(flat),
        activeDays: counts.length,
        average: flat.length ? total / flat.length : 0,
        streak: longestStreak(flat),
        streakSpan: longestStreakSpan(flat),
        current: currentStreak(flat),
        currentFrom: currentStreakStart(flat),
        first: flat.length ? flat[0].date : "",
        last: flat.length ? flat[flat.length - 1].date : "",
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

/** The date the run that is still going began, for the caption under it. */
function currentStreakStart(flat) {
    var n = currentStreak(flat);
    if (!n || !flat.length)
        return "";
    var end = flat.length - 1;
    if (flat[end].count === 0)
        end--;
    var start = end - n + 1;
    return start >= 0 ? flat[start].date : flat[0].date;
}

function longestStreak(flat) {
    var best = 0;
    var cur = 0;
    (flat || []).forEach(function (d) {
        if (d.count > 0) {
            cur++;
            if (cur > best)
                best = cur;
        } else {
            cur = 0;
        }
    });
    return best;
}

/** The dates the record streak ran between, for the caption under it. */
function longestStreakSpan(flat) {
    var best = 0;
    var span = ["", ""];
    var cur = 0;
    var start = "";
    (flat || []).forEach(function (d) {
        if (d.count > 0) {
            if (!cur)
                start = d.date;
            cur++;
            if (cur > best) {
                best = cur;
                span = [start, d.date];
            }
        } else {
            cur = 0;
            start = "";
        }
    });
    return span;
}

function level(count, ceiling) {
    if (!count)
        return 0;
    if (!ceiling || count >= ceiling)
        return 4;
    return Math.max(1, Math.min(4, Math.ceil(count / ceiling * 4)));
}

// ── time of day ─────────────────────────────────────────────────────────────

/**
 * When in the day this account works — 24 buckets in the viewer's own
 * timezone, which is the only one that answers the question being asked.
 *
 * `samples` is `[{ at: <ISO string or epoch ms>, count: n }]`. Providers hand
 * over whatever they have: GitHub push events with their commit counts,
 * GitLab's event feed, Forgejo's notification and commit timestamps.
 */
function clock(samples) {
    var hours = new Array(24);
    for (var i = 0; i < 24; i++)
        hours[i] = 0;

    var total = 0;
    (samples || []).forEach(function (s) {
        if (!s)
            return;
        var t = typeof s.at === "number" ? s.at : Date.parse(s.at);
        if (isNaN(t))
            return;
        var n = s.count === undefined || s.count === null ? 1 : s.count;
        if (n <= 0)
            return;
        hours[new Date(t).getHours()] += n;
        total += n;
    });
    if (!total)
        return null;

    var peak = 0;
    var peakHour = 0;
    for (var h = 0; h < 24; h++) {
        if (hours[h] > peak) {
            peak = hours[h];
            peakHour = h;
        }
    }
    return {
        hours: hours,
        peak: peak,
        peakHour: peakHour,
        total: total,
        tz: Fmt.tzLabel()
    };
}

/**
 * Coarse named buckets, derived from the 24-bin clock rather than from the
 * events a second time — one pass over the data, two ways of reading it.
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

function rhythm(clockOut) {
    if (!clockOut || !clockOut.total)
        return [];
    return RHYTHM_BUCKETS.map(function (b) {
        var n = 0;
        for (var h = b.from; h <= b.to; h++)
            n += clockOut.hours[h];
        return {
            name: b.id,
            count: n,
            share: n / clockOut.total * 100
        };
    }).sort(function (a, b) {
        return b.count - a.count;
    });
}

/** "morning" → "06:00–11:59", for the caption beside the dial. */
function bucketRange(name) {
    for (var i = 0; i < RHYTHM_BUCKETS.length; i++) {
        var b = RHYTHM_BUCKETS[i];
        if (b.id === name)
            return Fmt.hourLabel(b.from) + "–" + Fmt.hourLabel(b.to) + ":59";
    }
    return "";
}

// ── languages ───────────────────────────────────────────────────────────────

/**
 * Language mix by bytes, from the provider-neutral
 * `[{ name, bytes, color }]` list every forge can produce.
 */
function languages(list, topN) {
    var totals = {};
    var colours = {};
    var grand = 0;

    (list || []).forEach(function (l) {
        if (!l || !l.name)
            return;
        totals[l.name] = (totals[l.name] || 0) + (l.bytes || 0);
        if (l.color)
            colours[l.name] = l.color;
        grand += l.bytes || 0;
    });
    if (!grand)
        return [];

    var ranked = Object.keys(totals).map(function (n) {
        return {
            name: n,
            bytes: totals[n],
            color: colours[n] || "",
            share: totals[n] / grand * 100
        };
    });
    ranked.sort(function (a, b) {
        return b.bytes - a.bytes;
    });

    var n = topN || 6;
    var top = ranked.slice(0, n);
    var rest = ranked.slice(n).reduce(function (acc, l) {
        return acc + l.share;
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
