// Icon geometry for the Quickshell frontend.
//
// The Plasma build uses Kirigami.Icon and the user's icon theme. Hyprland has
// no such guarantee, so these are drawn as vector paths through QtQuick.Shapes
// — no image files, no icon theme, no extra module, and they tint to whatever
// colour the caller asks for.
//
// All paths are authored against a 16×16 box; Icon.qml scales from there.
.pragma library

/**
 * fill: an SVG path filled with the icon colour.
 * stroke: an SVG path stroked at `w` units, for shapes that read better as
 *         outlines at 14–16 px than as filled silhouettes.
 */
var GLYPHS = {
    bell: {
        fill: "M8 16a2 2 0 0 0 1.985-1.75c.017-.137-.097-.25-.235-.25h-3.5c-.138 0-.252.113-.235.25A2 2 0 0 0 8 16ZM3 5a5 5 0 0 1 10 0v2.947c0 .05.015.098.042.139l1.703 2.555A1.519 1.519 0 0 1 13.482 13H2.518a1.516 1.516 0 0 1-1.263-2.36l1.703-2.554A.255.255 0 0 0 3 7.947Z"
    },
    play: {
        fill: "M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Zm4.879-2.773 4.264 2.559a.25.25 0 0 1 0 .428l-4.264 2.559A.25.25 0 0 1 6 10.559V5.441a.25.25 0 0 1 .379-.214Z"
    },
    pull: {
        fill: "M1.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 1.5 3.25Zm5.677-.177L9.573.677A.25.25 0 0 1 10 .854V2.5h1A2.5 2.5 0 0 1 13.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L7.177 3.427a.25.25 0 0 1 0-.354ZM3.75 2.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm0 9.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm8.5 0a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Z"
    },
    issue: {
        fill: "M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Z"
    },
    pulse: {
        stroke: "M1 8h3l2.1-5.2L9.2 13l2-5H15",
        w: 1.5
    },
    person: {
        fill: "M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0 1.5c-3 0-5.5 1.7-5.5 3.4V15h11v-2.1c0-1.7-2.5-3.4-5.5-3.4Z"
    },
    // A small robot: head, antenna, two eyes. Abstract enough not to imitate
    // GitHub's mark, concrete enough to read at 15 px.
    copilot: {
        stroke: "M3 7.6a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v3a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3ZM8 5.6V3.9",
        w: 1.4,
        extra: "M8 1.5a1.15 1.15 0 1 1 0 2.3 1.15 1.15 0 0 1 0-2.3ZM6.1 8.6a1.05 1.05 0 1 1 0 2.1 1.05 1.05 0 0 1 0-2.1Zm3.8 0a1.05 1.05 0 1 1 0 2.1 1.05 1.05 0 0 1 0-2.1Z"
    },
    search: {
        fill: "M10.68 11.74a6 6 0 1 1 1.06-1.06l3.04 3.04a.75.75 0 1 1-1.06 1.06ZM11.5 7a4.5 4.5 0 1 0-9 0 4.5 4.5 0 0 0 9 0Z"
    },
    group: {
        fill: "M3 2a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Zm0 4.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Zm0 4.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM6.4 2.7h8v1.6h-8Zm0 4.5h8v1.6h-8Zm0 4.5h8v1.6h-8Z"
    },
    refresh: {
        fill: "M8 2.5a5.487 5.487 0 0 0-4.131 1.869l1.204 1.204A.25.25 0 0 1 4.896 6H1.25A.25.25 0 0 1 1 5.75V2.104a.25.25 0 0 1 .427-.177l1.38 1.38A7.001 7.001 0 0 1 14.95 7.16a.75.75 0 1 1-1.49.178A5.5 5.5 0 0 0 8 2.5ZM1.705 8.005a.75.75 0 0 1 .834.656 5.5 5.5 0 0 0 9.592 2.97l-1.204-1.204a.25.25 0 0 1 .177-.427h3.646a.25.25 0 0 1 .25.25v3.646a.25.25 0 0 1-.427.177l-1.38-1.38A7.001 7.001 0 0 1 1.05 8.84a.75.75 0 0 1 .656-.834Z"
    },
    // A hollow ring with short, thick teeth. The earlier version had a filled
    // hub and long thin spokes, which reads as a sun, not a cog.
    gear: {
        stroke: "M8 3.4a4.6 4.6 0 1 0 0 9.2 4.6 4.6 0 0 0 0-9.2Z",
        w: 2,
        extra: "M8 1v1.8M8 13.2V15M1 8h1.8M13.2 8H15M3.05 3.05l1.25 1.25M11.7 11.7l1.25 1.25M12.95 3.05 11.7 4.3M4.3 11.7l-1.25 1.25",
        extraW: 2.6
    },
    close: {
        stroke: "M3.5 3.5 12.5 12.5M12.5 3.5 3.5 12.5",
        w: 1.8
    },
    external: {
        fill: "M3.75 2h3.5a.75.75 0 0 1 0 1.5h-3.5a.25.25 0 0 0-.25.25v8.5c0 .138.112.25.25.25h8.5a.25.25 0 0 0 .25-.25v-3.5a.75.75 0 0 1 1.5 0v3.5A1.75 1.75 0 0 1 12.25 14h-8.5A1.75 1.75 0 0 1 2 12.25v-8.5C2 2.784 2.784 2 3.75 2Zm6.854-1h4.146a.25.25 0 0 1 .25.25v4.146a.75.75 0 0 1-1.5 0V2.75h-2.682l-5.36 5.36a.75.75 0 0 1-1.06-1.06l5.36-5.36Z"
    },
    chevron: {
        stroke: "m4 6.2 4 4 4-4",
        w: 1.7
    },
    mailRead: {
        stroke: "M1.7 6.4 8 2.1l6.3 4.3v6.1a1 1 0 0 1-1 1H2.7a1 1 0 0 1-1-1Zm0 0 6.3 4.3 6.3-4.3",
        w: 1.35
    },
    at: {
        stroke: "M10.5 8a2.5 2.5 0 1 0-2.5 2.5M10.5 8v1.3a2 2 0 0 0 4 0V8A6.5 6.5 0 1 0 11 13.7",
        w: 1.3
    },
    shield: {
        stroke: "M8 1.6 13.9 3.8v4.3c0 3.2-2.4 5.9-5.9 6.7-3.5-.8-5.9-3.5-5.9-6.7V3.8ZM8 5.4v3",
        w: 1.4
    },
    merge: {
        stroke: "M4 4.9v6M5.7 3.4c3.3 0 4.6 1 4.8 3",
        w: 1.4,
        extra: "M4 1.5a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Zm0 9.6a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Zm8-6.5a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Z",
        extraW: 1.4
    },
    check: {
        fill: "M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 1.06-1.06L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"
    },
    cross: {
        fill: "M3.72 3.72a.75.75 0 0 1 1.06 0L8 6.94l3.22-3.22a.75.75 0 1 1 1.06 1.06L9.06 8l3.22 3.22a.75.75 0 1 1-1.06 1.06L8 9.06l-3.22 3.22a.75.75 0 0 1-1.06-1.06L6.94 8 3.72 4.78a.75.75 0 0 1 0-1.06Z"
    },
    clock: {
        stroke: "M8 1.6a6.4 6.4 0 1 0 0 12.8A6.4 6.4 0 0 0 8 1.6Zm0 2.8V8.3l2.5 1.6",
        w: 1.4
    },
    dot: {
        fill: "M8 4.4a3.6 3.6 0 1 1 0 7.2 3.6 3.6 0 0 1 0-7.2Z"
    },
    comment: {
        stroke: "M2 3.2h12a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H6.5L3 14.2v-3H2a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1Z",
        w: 1.35
    },
    alert: {
        stroke: "M8 1.9 15 14H1ZM8 6v3.4",
        w: 1.4,
        extra: "M8 11a.95.95 0 1 0 0 1.9A.95.95 0 0 0 8 11Z",
        extraW: 0
    }
};

/** Reason → glyph, mirroring Format.reasonIcon() on the Plasma side. */
var BY_REASON = {
    review_requested: "pull",
    approval_requested: "pull",
    mention: "at",
    team_mention: "at",
    assign: "issue",
    security_alert: "shield",
    security_advisory_credit: "shield",
    ci_activity: "play",
    comment: "comment",
    state_change: "merge",
    subscribed: "bell",
    manual: "bell",
    author: "comment",
    invitation: "person"
};

function forItem(item) {
    if (!item)
        return "bell";
    switch (item.kind) {
    case "notification":
        return BY_REASON[item.reason] || "bell";
    case "run":
        if (item.running)
            return "refresh";
        return item.tone === "negative" ? "cross" : item.tone === "positive" ? "check" : "clock";
    case "pull_request":
        return item.merged ? "merge" : "pull";
    default:
        return "issue";
    }
}

function forTab(id) {
    switch (id) {
    case "inbox":
        return "bell";
    case "actions":
        return "play";
    case "pulls":
        return "pull";
    case "issues":
        return "issue";
    case "profile":
        return "person";
    case "copilot":
        return "copilot";
    case "status":
        return "pulse";
    default:
        return "dot";
    }
}
