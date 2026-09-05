// Breeze icon names → Gitpulse's own glyph keys.
//
// Every name the widget asks Kirigami.Icon for, mapped to the nearest glyph in
// hyprland/Icons.js so the offscreen Plasma render shows icons instead of
// empty boxes. The sources are Format.js (reason, run and pull-request icon
// tables), the tab list in main.qml, the Profile tab's stat tiles and the
// chrome buttons.
//
// Approximate on purpose: Breeze has a star for "rating" and this glyph set
// does not. A screenshot from the stub shows an icon of the right meaning, not
// the exact art Breeze draws.
.pragma library

var GLYPH = {
    // ── notification reasons (Format.reasonIcon) ────────────────────────────
    "mail-message": "bell",
    "view-task": "issue",
    "document-edit": "comment",
    "media-playback-start": "play",
    "irc-voice": "comment",
    "list-add-user": "person",
    "vcs-merge-request": "pull",
    "security-medium": "shield",
    "vcs-merge": "merge",
    "view-visible": "bell",
    "system-users": "person",

    // ── run conclusions (Format.runIcon) ────────────────────────────────────
    "state-sync": "refresh",
    "clock": "clock",
    "dialog-ok": "check",
    "dialog-error": "cross",
    "dialog-warning": "alert",
    "dialog-cancel": "cross",

    // ── pull request states (Format.pullIcon) ───────────────────────────────
    "vcs-branch": "pull",
    "vcs-removed": "cross",

    // ── tabs ────────────────────────────────────────────────────────────────
    "user-identity": "person",
    "computer": "copilot",
    "network-server": "pulse",

    // ── profile stat tiles ──────────────────────────────────────────────────
    "rating": "check",
    "vcs-commit": "dot",
    "checkmark": "check",
    "folder-git": "group",
    "user-group-new": "person",

    // ── chrome ──────────────────────────────────────────────────────────────
    "search": "search",
    "view-list-tree": "group",
    "view-refresh": "refresh",
    "configure": "gear",
    "dialog-close": "close",
    "edit-clear": "close",
    "edit-copy": "external",
    "edit-undo": "refresh",
    "emblem-ok": "check",
    "expand": "chevron",
    "internet-services": "external",
    "list-add": "dot",
    "list-remove": "cross",
    "mail-mark-read": "mailRead",
    "notifications": "bell",
    "notifications-disabled": "bell",
    "package-installed-updated": "check",
    "network-disconnect": "alert",
    "object-locked": "shield",
    "password-show-on": "search",
    "password-show-off": "search",
    "view-hidden": "close"
};

function glyphFor(name) {
    return GLYPH[name] || "";
}
