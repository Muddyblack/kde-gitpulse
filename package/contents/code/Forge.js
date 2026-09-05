// Gitpulse — the forge registry.
//
// One account list, three providers, one dispatch table. Engine.qml talks only
// to this file, so adding a fourth forge is a new module plus a row in
// PROVIDERS — not a change to the engine, the badge arithmetic or either
// frontend.
//
// An account is:
//   { id, provider, host, token, graphqlToken, label, enabled,
//     login, userId, avatarUrl }
// The first six are persisted by the host; the last three are filled in by the
// identity call and are not written back to disk.
.pragma library

.import "Http.js" as Http
.import "GitHub.js" as GitHub
.import "GitLab.js" as GitLab
.import "Forgejo.js" as Forgejo

/**
 * Everything the settings UI needs to describe a forge, so neither frontend
 * hard-codes a provider name, a token URL or a scope list.
 */
var PROVIDERS = [
    {
        id: GitHub.ID,
        short: "GH",
        label: GitHub.LABEL,
        module: GitHub,
        defaultHost: GitHub.DEFAULT_HOST,
        // GitHub Enterprise Server is the same API on a different host.
        selfHosted: true,
        hostHint: "https://github.example.com",
        tokenPath: "/settings/tokens",
        tokenPlaceholder: "ghp_… or github_pat_…",
        scopes: "notifications, repo (read), read:org, read:user",
        icon: "github",
        brand: "#8b949e",
        cli: "gh auth token"
    },
    {
        id: GitLab.ID,
        short: "GL",
        label: GitLab.LABEL,
        module: GitLab,
        defaultHost: GitLab.DEFAULT_HOST,
        selfHosted: true,
        hostHint: "https://gitlab.example.com",
        tokenPath: "/-/user_settings/personal_access_tokens",
        tokenPlaceholder: "glpat-…",
        scopes: "read_api, read_user",
        icon: "gitlab",
        brand: "#fc6d26",
        cli: ""
    },
    {
        id: Forgejo.ID,
        short: "CB",
        label: Forgejo.LABEL,
        module: Forgejo,
        defaultHost: Forgejo.DEFAULT_HOST,
        selfHosted: true,
        // The same module serves any Forgejo or Gitea instance.
        hostHint: "https://forgejo.example.com",
        tokenPath: "/user/settings/applications",
        tokenPlaceholder: "a Forgejo access token",
        scopes: "read:notification, read:repository, read:issue, read:user",
        icon: "codeberg",
        brand: "#2185d0",
        cli: ""
    }
];

function descriptor(providerId) {
    for (var i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].id === providerId)
            return PROVIDERS[i];
    }
    return PROVIDERS[0];
}

function moduleFor(acct) {
    return descriptor(acct && acct.provider).module;
}

function capabilities(acct) {
    return moduleFor(acct).CAPABILITIES;
}

/** True when at least one enabled account can serve `source`. */
function anySupports(accounts, source) {
    return (accounts || []).some(function (a) {
        return capabilities(a)[source];
    });
}

// ── the account list ────────────────────────────────────────────────────────

function blank(providerId) {
    var d = descriptor(providerId || GitHub.ID);
    return {
        // Random rather than sequential: an id is a cache and de-duplication
        // key, and reusing a removed account's id would resurrect its rows.
        id: "acc" + Math.floor(Math.random() * 0x7fffffff).toString(36) + Date.now().toString(36).slice(-4),
        provider: d.id,
        host: "",
        token: "",
        graphqlToken: "",
        label: "",
        useCli: false,
        enabled: true
    };
}

function normalise(acct) {
    var d = descriptor(acct && acct.provider);
    var host = Http.trimHost(acct && acct.host) || d.defaultHost;
    return {
        id: (acct && acct.id) || d.id,
        provider: d.id,
        host: host,
        token: (acct && acct.token) || "",
        graphqlToken: (acct && acct.graphqlToken) || "",
        label: (acct && acct.label) || "",
        useCli: !!(acct && acct.useCli),
        enabled: !acct || acct.enabled !== false,
        // Runtime-only, filled in by the identity call.
        login: (acct && acct.login) || "",
        userId: (acct && acct.userId) || 0,
        avatarUrl: (acct && acct.avatarUrl) || ""
    };
}

/** Persisted JSON → accounts. Anything unparseable yields an empty list. */
function parse(json) {
    if (!json)
        return [];
    var raw = json;
    if (typeof raw === "string") {
        try {
            raw = JSON.parse(raw);
        } catch (e) {
            return [];
        }
    }
    if (!raw || !raw.length)
        return [];
    return raw.map(normalise);
}

function stringify(accounts) {
    return JSON.stringify((accounts || []).map(function (a) {
        // Only the persisted half. Writing `login` back would make the config
        // file change on every poll.
        return {
            id: a.id,
            provider: a.provider,
            host: a.host,
            token: a.token,
            graphqlToken: a.graphqlToken,
            label: a.label,
            useCli: a.useCli,
            enabled: a.enabled
        };
    }));
}

/**
 * Accounts as the engine should poll them.
 *
 * `cliToken` is whatever `gh auth token` produced, which the host resolves
 * because reading it needs a process and this file has none. Accounts with no
 * usable credential are dropped rather than polled: an empty token is a
 * guaranteed 401, once per interval, forever.
 */
function active(accounts, cliToken) {
    return (accounts || []).map(function (a) {
        if (!a.useCli)
            return a;
        var copy = normalise(a);
        copy.token = cliToken || "";
        return copy;
    }).filter(function (a) {
        return a.enabled && a.token !== "";
    });
}

/**
 * Migration from the single-token configuration.
 *
 * Gitpulse 1.x had one GitHub token and no account list. Rather than ask
 * existing users to re-enter it, a legacy token becomes the first account —
 * and keeps the id "github" so its cached bodies and item ids stay valid
 * across the upgrade.
 */
function migrate(token, graphqlToken, useCli) {
    if (!token && !useCli)
        return [];
    var a = blank(GitHub.ID);
    a.id = "github";
    a.token = token || "";
    a.graphqlToken = graphqlToken || "";
    a.useCli = !!useCli;
    return [a];
}

/** A short, unambiguous name for the account chip on a row. */
function displayName(acct) {
    if (!acct)
        return "";
    if (acct.label)
        return acct.label;
    var d = descriptor(acct.provider);
    var host = Http.trimHost(acct.host);
    // Only say "GitLab (git.example.com)" when it is not the public instance —
    // a chip that always repeats "gitlab.com" carries no information.
    if (host && host !== d.defaultHost)
        return d.label + " (" + host.replace(/^https?:\/\//, "") + ")";
    return d.label;
}

/**
 * Two letters for a dense row: "GH", "GL", "CB".
 *
 * Deliberately not the forge's brand colour — this widget follows the desktop
 * palette everywhere else, and three brand colours in a notification list read
 * as decoration rather than as information.
 */
function shortName(providerId) {
    return descriptor(providerId).short;
}

function tokenUrl(acct) {
    var d = descriptor(acct && acct.provider);
    return (Http.trimHost(acct && acct.host) || d.defaultHost) + d.tokenPath;
}

// ── dispatch ────────────────────────────────────────────────────────────────
//
// Each of these is "ask this account's provider", and exists so Engine.qml can
// stay free of provider names.

function viewer(acct, cb) {
    return moduleFor(acct).viewer(acct, cb);
}

function inbox(acct, opts, cb) {
    return moduleFor(acct).inbox(acct, opts, cb);
}

function work(acct, opts, cb) {
    return moduleFor(acct).work(acct, opts, cb);
}

function pipelines(acct, opts, cb) {
    return moduleFor(acct).pipelines(acct, opts, cb);
}

function profile(acct, cb) {
    return moduleFor(acct).profile(acct, cb);
}

/**
 * The hour dial and, where the forge has one, the contribution calendar.
 *
 * GitHub splits this: real commit timestamps come from GraphQL when the token
 * allows it, and from the public event feed when it does not. GitLab and
 * Forgejo each have a single call that answers both.
 */
function activity(acct, hint, cb) {
    var mod = moduleFor(acct);
    if (mod.activity)
        return mod.activity(acct, cb);
    if (!mod.clock)
        return Http.empty(cb, null);
    return mod.clock(acct, hint, function (res) {
        if (res.ok && res.data) {
            cb({
                ok: true,
                status: res.status,
                error: "",
                message: "",
                data: {
                    calendar: null,
                    clock: res.data
                },
                notModified: false,
                rate: res.rate,
                retryAfter: 0
            });
            return;
        }
        // GraphQL refused, or there were no repositories to ask about — the
        // public event feed still yields a usable shape.
        mod.events(acct, function (fallback) {
            cb({
                ok: true,
                status: fallback.status,
                error: "",
                message: "",
                data: {
                    calendar: null,
                    clock: fallback.ok ? fallback.data : null
                },
                notModified: false,
                rate: fallback.rate,
                retryAfter: 0
            });
        });
    });
}

function languages(acct, hint, cb) {
    var mod = moduleFor(acct);
    if (!mod.languages)
        return Http.empty(cb, []);
    return mod.languages(acct, hint, cb);
}

function markRead(acct, item, cb) {
    return moduleFor(acct).markRead(acct, item, cb);
}

function markAllRead(acct, stamp, cb) {
    return moduleFor(acct).markAllRead(acct, stamp, cb);
}

function unsubscribe(acct, item, cb) {
    return moduleFor(acct).unsubscribe(acct, item, cb);
}

function rerun(acct, item, cb) {
    return moduleFor(acct).rerun(acct, item, cb);
}

function notificationsUrl(acct) {
    return moduleFor(acct).notificationsUrl(acct);
}

function repoUrl(acct, fullName) {
    return moduleFor(acct).repoUrl(acct, fullName);
}

// ── URLs from an item ───────────────────────────────────────────────────────
//
// An item already carries the host and provider it came from, so the row
// menus can build a link without looking its account back up — which also
// means a link still works for an item whose account was removed while the
// popup was open.

function itemRepoUrl(item) {
    if (!item || !item.repo)
        return "";
    return (item.host || descriptor(item.provider).defaultHost) + "/" + item.repo;
}

/** The three forges spell "pull request number N" three different ways. */
function itemPullUrl(item) {
    if (!item || !item.repo || !item.pullNumber)
        return "";
    var base = itemRepoUrl(item);
    switch (item.provider) {
    case GitLab.ID:
        return base + "/-/merge_requests/" + item.pullNumber;
    case Forgejo.ID:
        return base + "/pulls/" + item.pullNumber;
    default:
        return base + "/pull/" + item.pullNumber;
    }
}
