// Gitpulse — HTTP transport, shared by every forge.
//
// Everything here runs on QML's own XMLHttpRequest and JSON.parse. There is no
// Python, no curl, no jq: the widget is installable as a plain plasmoid and
// works the moment it is added, on any distribution.
//
// Every call takes a node-style callback `cb(res)` where res is:
//   { ok, status, error, message, data, notModified, rate, retryAfter }
// `error` is one of ERR.* and is the only thing the UI should branch on —
// HTTP status codes stay in here. GitHub, GitLab and Forgejo all speak this
// same vocabulary, so nothing above this file branches on which forge replied.
.pragma library

/** The complete set of failure modes the UI has to render. */
var ERR = {
    NONE: "",
    NO_TOKEN: "no_token", // nothing configured yet
    AUTH: "auth", // 401 — token invalid, expired or revoked
    FORBIDDEN: "forbidden", // 403 — token lacks the scope for this endpoint
    RATE_LIMIT: "rate_limit", // 403/429 — primary or secondary limit
    NOT_FOUND: "not_found", // 404 — also what forges return for "no access"
    SERVER: "server", // 5xx — the forge's problem, retry later
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
// A 304 does not count against GitHub's rate limit, so every GET carries the
// previous ETag. This is the single reason the widget can poll the inbox every
// 60 s and still use a rounding error of the hourly budget. GitLab and Forgejo
// send ETags too, where the saving is bandwidth rather than budget.

var _cache = {};
/**
 * Cap on cached bodies.
 *
 * Keys are per-URL, and the per-repository pipeline URLs grow with every
 * repository a user has ever had in their watch list — an allowlist edit or a
 * push to an old repository adds one and nothing ever removed it. Bounded
 * here, oldest first, so a session left running for weeks cannot accumulate
 * response bodies indefinitely.
 */
var MAX_CACHE_ENTRIES = 160;

function clearCache() {
    _cache = {};
}

/** Drop cached bodies for one prefix — used when a token or filter changes. */
function invalidate(prefix) {
    for (var k in _cache) {
        if (!prefix || k.indexOf(prefix) === 0)
            delete _cache[k];
    }
}

function _remember(key, entry) {
    _cache[key] = entry;
    var keys = Object.keys(_cache);
    if (keys.length <= MAX_CACHE_ENTRIES)
        return;
    keys.sort(function (a, b) {
        return _cache[a].at - _cache[b].at;
    });
    for (var i = 0; i < keys.length - MAX_CACHE_ENTRIES; i++)
        delete _cache[keys[i]];
}

/** Diagnostics for the settings page; nothing branches on it. */
function cacheSize() {
    return Object.keys(_cache).length;
}

// ── core request ────────────────────────────────────────────────────────────

function _rateFrom(xhr) {
    function num(h) {
        var v = xhr.getResponseHeader(h);
        return v === null || v === "" ? -1 : parseInt(v, 10);
    }
    // GitHub spells it x-ratelimit-*; GitLab spells it ratelimit-*; Forgejo
    // sends neither unless the instance opts in.
    var limit = num("x-ratelimit-limit");
    if (limit < 0)
        limit = num("ratelimit-limit");
    if (limit < 0)
        return null;
    var remaining = num("x-ratelimit-remaining");
    if (remaining < 0)
        remaining = num("ratelimit-remaining");
    var used = num("x-ratelimit-used");
    var reset = num("x-ratelimit-reset");
    if (reset < 0)
        reset = num("ratelimit-reset");
    return {
        limit: limit,
        remaining: remaining,
        used: used,
        reset: reset // epoch seconds
    };
}

function _messageOf(body) {
    if (!body)
        return "";
    try {
        var j = JSON.parse(body);
        // GitHub: message. GitLab: message or error. Forgejo: message.
        var m = j.message || j.error || j.error_description || "";
        return typeof m === "string" ? m : JSON.stringify(m);
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
 * opts: { url, method, token, scheme, body, accept, headers, conditional,
 *         cacheKey }
 * `scheme` is the Authorization prefix — "Bearer" for GitHub and Forgejo,
 * "Bearer" for GitLab OAuth, and GitLab personal tokens go in their own
 * header instead (see `headers`).
 *
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
    xhr.setRequestHeader("Accept", opts.accept || "application/json");
    if (opts.token)
        xhr.setRequestHeader("Authorization", (opts.scheme || "Bearer") + " " + opts.token);
    if (opts.headers) {
        for (var h in opts.headers) {
            if (opts.headers[h])
                xhr.setRequestHeader(h, opts.headers[h]);
        }
    }
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
                _remember(key, {
                    etag: etag,
                    lastModified: lastMod,
                    body: parsed,
                    at: Date.now()
                });
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

/** The canonical "nothing is configured" answer, so every provider agrees. */
function noToken(cb) {
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

/** A synthetic success, for a source a forge simply does not have. */
function empty(cb, data) {
    cb({
        ok: true,
        status: 0,
        error: ERR.NONE,
        message: "",
        data: data === undefined ? [] : data,
        notModified: false,
        rate: null,
        retryAfter: 0
    });
    return null;
}

/** "https://codeberg.org/" → "https://codeberg.org". */
function trimHost(host) {
    return String(host || "").trim().replace(/\/+$/, "");
}

function query(params) {
    var out = [];
    for (var k in params) {
        var v = params[k];
        if (v === undefined || v === null || v === "")
            continue;
        out.push(encodeURIComponent(k) + "=" + encodeURIComponent(v));
    }
    return out.length ? "?" + out.join("&") : "";
}
