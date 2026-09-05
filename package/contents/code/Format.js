// Gitpulse — presentation helpers shared by the Plasma and Quickshell frontends.
//
// Pure functions only: no QML types, no imports. tests/run-tests.qml exercises
// this file directly, and hyprland/ imports the very same copy.
.pragma library

// ── time ────────────────────────────────────────────────────────────────────

/** Milliseconds since `iso`, or NaN when the timestamp is unusable. */
function ageMs(iso, now) {
    if (!iso)
        return NaN;
    var t = Date.parse(iso);
    if (isNaN(t))
        return NaN;
    return (now === undefined ? Date.now() : now) - t;
}

/**
 * Compact relative time: "now", "4m", "3h", "2d", "5w", "3mo", "2y".
 *
 * Deliberately unit-suffixed rather than "4 minutes ago" — these sit in a
 * 40 px column next to every row and must never wrap or elide.
 */
function relative(iso, now) {
    var ms = ageMs(iso, now);
    if (isNaN(ms))
        return "";
    if (ms < 0)
        ms = 0;
    var s = Math.floor(ms / 1000);
    if (s < 45)
        return "now";
    var m = Math.floor(s / 60);
    if (m < 60)
        return m + "m";
    var h = Math.floor(m / 60);
    if (h < 24)
        return h + "h";
    var d = Math.floor(h / 24);
    if (d < 7)
        return d + "d";
    var w = Math.floor(d / 7);
    if (d < 30)
        return w + "w";
    var mo = Math.floor(d / 30);
    if (mo < 12)
        return mo + "mo";
    return Math.floor(d / 365) + "y";
}

/**
 * "4m ago", "just now".
 *
 * `relative()` alone yields "now", and every caller pasted " ago" after it —
 * which spelled "now ago" for anything fresher than 45 seconds, on the footer
 * that updates every minute and therefore said it most of the time.
 */
function since(iso, now) {
    var r = relative(iso, now);
    if (r === "")
        return "";
    return r === "now" ? "just now" : r + " ago";
}

/** "in 4m" / "in 12s" — used for rate-limit resets and the next-poll countdown. */
function until(seconds) {
    if (seconds === undefined || seconds === null || seconds <= 0)
        return "now";
    if (seconds < 60)
        return Math.round(seconds) + "s";
    var m = Math.floor(seconds / 60);
    if (m < 60)
        return m + "m";
    return Math.floor(m / 60) + "h " + (m % 60) + "m";
}

/** Local wall-clock time for the "new since" divider. */
function clock(date) {
    var d = date || new Date();
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
}

/** "06" — a zero-padded hour, for clock ticks and bucket ranges. */
function hourLabel(hour) {
    return ("0" + Math.max(0, Math.min(23, hour))).slice(-2) + ":00";
}

/**
 * The viewer's own UTC offset, spelled the way the profile card spells it:
 * "utc+2", "utc-5:30", "utc". Everything time-of-day in Gitpulse is in local
 * time, and saying so is the difference between a chart people trust and one
 * they quietly assume is wrong.
 */
function tzLabel(at) {
    // getTimezoneOffset() is minutes *behind* UTC, hence the negation.
    var total = -(at || new Date()).getTimezoneOffset();
    if (total === 0)
        return "utc";
    var sign = total >= 0 ? "+" : "-";
    var hours = Math.floor(Math.abs(total) / 60);
    var minutes = Math.abs(total) % 60;
    return "utc" + sign + hours + (minutes ? ":" + ("0" + minutes).slice(-2) : "");
}

/** ISO date (UTC) for heatmap cell keys. */
function isoDate(date) {
    return date.getUTCFullYear() + "-" + ("0" + (date.getUTCMonth() + 1)).slice(-2) + "-" + ("0" + date.getUTCDate()).slice(-2);
}

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/**
 * "2026-04-30" → "Apr 30", or "Apr 30, 2025" when it is not this year.
 *
 * The streak captions sit in a third of a 432 px popup. A full ISO date does
 * not fit there and elides to "2026-04-30 — 2026-05…", which is worse than no
 * caption at all.
 */
function shortDate(iso, now) {
    if (!iso)
        return "";
    var parts = String(iso).split("-");
    if (parts.length < 3)
        return String(iso);
    var year = parseInt(parts[0], 10);
    var month = parseInt(parts[1], 10) - 1;
    var day = parseInt(parts[2], 10);
    if (isNaN(year) || isNaN(month) || isNaN(day) || month < 0 || month > 11)
        return String(iso);
    var thisYear = (now === undefined ? new Date() : new Date(now)).getFullYear();
    return MONTHS[month] + " " + day + (year === thisYear ? "" : ", " + year);
}

/** ISO date in the viewer's own timezone, for event-derived day buckets. */
function localDate(date) {
    var d = date || new Date();
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2);
}

// ── numbers ─────────────────────────────────────────────────────────────────

/** 1420 → "1.4k", 1_240_000 → "1.2M". Keeps stat tiles a fixed width. */
function compact(n) {
    if (n === undefined || n === null || isNaN(n))
        return "—";
    var a = Math.abs(n);
    if (a < 1000)
        return String(Math.round(n));
    if (a < 1000000)
        return trimZero((n / 1000).toFixed(1)) + "k";
    return trimZero((n / 1000000).toFixed(1)) + "M";
}

function trimZero(s) {
    return s.replace(/\.0$/, "");
}

function percent(part, whole) {
    if (!whole)
        return 0;
    return Math.max(0, Math.min(100, Math.round(part / whole * 100)));
}

/** "+1.4k" / "+12" — compact additions count for diff badges. */
function diffAdditions(n) {
    if (n === undefined || n === null || isNaN(n) || n < 0)
        return "";
    return "+" + compact(n);
}

/** "-200" / "-1.2k" — compact deletions count for diff badges. */
function diffDeletions(n) {
    if (n === undefined || n === null || isNaN(n) || n < 0)
        return "";
    return "-" + compact(n);
}

// ── strings ─────────────────────────────────────────────────────────────────

/** "muddyblack/nixos-config" → "nixos-config". */
function repoName(fullName) {
    if (!fullName)
        return "";
    var i = fullName.lastIndexOf("/");
    return i < 0 ? fullName : fullName.slice(i + 1);
}

/** "review_requested" → "review requested". */
function humanise(token) {
    if (!token)
        return "";
    return String(token).replace(/_/g, " ");
}

/**
 * Short label for a notification reason, sized for a pill.
 * Unknown reasons fall through to their humanised form rather than "unknown",
 * because GitHub adds new ones and a wrong label beats a missing one.
 */
var REASON_LABEL = {
    approval_requested: "approval",
    assign: "assigned",
    author: "author",
    ci_activity: "ci",
    comment: "comment",
    invitation: "invite",
    manual: "subscribed",
    member_feature_requested: "feature",
    mention: "mention",
    review_requested: "review",
    security_alert: "security",
    security_advisory_credit: "advisory",
    state_change: "state",
    subscribed: "watching",
    team_mention: "team"
};

function reasonLabel(reason) {
    return REASON_LABEL[reason] || humanise(reason);
}

/**
 * Icon-theme name per reason. Verified against Breeze; anything missing falls
 * back to a name Breeze definitely ships, so a sparse icon theme degrades to a
 * generic glyph instead of an empty box.
 */
var REASON_ICON = {
    assign: "view-task",
    author: "document-edit",
    ci_activity: "media-playback-start",
    comment: "irc-voice",
    invitation: "list-add-user",
    mention: "mail-message",
    review_requested: "vcs-merge-request",
    security_alert: "security-medium",
    security_advisory_credit: "security-medium",
    state_change: "vcs-merge",
    subscribed: "view-visible",
    team_mention: "system-users"
};

function reasonIcon(reason) {
    return REASON_ICON[reason] || "mail-message";
}

/**
 * A stable colour for a language the forge did not colour itself.
 *
 * GitHub sends linguist's own colours; GitLab and Forgejo send none, and a
 * language bar drawn entirely in the disabled-text colour is a grey smear.
 * The hash is deterministic, so the same language keeps the same hue between
 * launches, and the fixed saturation and lightness keep every stripe legible
 * on both a light and a dark surface.
 */
function languageColor(name) {
    if (!name)
        return "";
    var h = 0;
    for (var i = 0; i < name.length; i++)
        h = (h * 31 + name.charCodeAt(i)) % 360;
    return hsl(h, 0.58, 0.55);
}

function hsl(h, s, l) {
    function f(n) {
        var k = (n + h / 30) % 12;
        var a = s * Math.min(l, 1 - l);
        var v = l - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
        return ("0" + Math.round(v * 255).toString(16)).slice(-2);
    }
    return "#" + f(0) + f(8) + f(4);
}

// ── run / check conclusions ─────────────────────────────────────────────────

/**
 * Maps an Actions run to a semantic tone the UI turns into a Kirigami colour.
 * Tones are the only vocabulary the QML knows: "positive", "negative",
 * "neutral", "accent", "muted".
 */
function runTone(status, conclusion) {
    if (status === "in_progress" || status === "queued" || status === "waiting" || status === "requested" || status === "pending")
        return "accent";
    switch (conclusion) {
    case "success":
        return "positive";
    case "failure":
    case "timed_out":
    case "startup_failure":
        return "negative";
    case "cancelled":
    case "skipped":
    case "neutral":
        return "muted";
    case "action_required":
    case "stale":
        return "neutral";
    default:
        return "muted";
    }
}

function runLabel(status, conclusion) {
    if (status === "queued" || status === "waiting" || status === "requested")
        return "queued";
    if (status === "in_progress" || status === "pending")
        return "running";
    return humanise(conclusion || status || "unknown");
}

function runIcon(status, conclusion) {
    if (status === "in_progress" || status === "pending")
        return "state-sync";
    if (status === "queued" || status === "waiting" || status === "requested")
        return "clock";
    switch (conclusion) {
    case "success":
        return "dialog-ok";
    case "failure":
    case "timed_out":
    case "startup_failure":
        return "dialog-error";
    case "action_required":
        return "dialog-warning";
    default:
        return "dialog-cancel";
    }
}

// ── pull requests ───────────────────────────────────────────────────────────

function pullTone(state, draft, merged) {
    if (merged)
        return "accent";
    if (draft)
        return "muted";
    return state === "closed" ? "negative" : "positive";
}

function pullLabel(state, draft, merged) {
    if (merged)
        return "merged";
    if (draft)
        return "draft";
    return state === "closed" ? "closed" : "open";
}

function pullIcon(state, draft, merged) {
    if (merged)
        return "vcs-merge";
    if (draft)
        return "vcs-branch";
    return state === "closed" ? "vcs-removed" : "vcs-merge-request";
}

// ── githubstatus.com ────────────────────────────────────────────────────────

function componentTone(status) {
    switch (status) {
    case "operational":
        return "positive";
    case "degraded_performance":
    case "partial_outage":
        return "neutral";
    case "major_outage":
        return "negative";
    case "under_maintenance":
        return "accent";
    default:
        return "muted";
    }
}

function indicatorTone(indicator) {
    switch (indicator) {
    case "none":
        return "positive";
    case "minor":
        return "neutral";
    case "major":
    case "critical":
        return "negative";
    case "maintenance":
        return "accent";
    default:
        return "muted";
    }
}

function impactTone(impact) {
    switch (impact) {
    case "critical":
    case "major":
        return "negative";
    case "minor":
        return "neutral";
    case "maintenance":
        return "accent";
    default:
        return "muted";
    }
}
