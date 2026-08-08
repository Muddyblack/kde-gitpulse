// Palette for the Quickshell frontend.
//
// The Plasma build reads Kirigami.Theme, which does not exist outside Plasma.
// Rather than make Hyprland users install Kirigami, this is the equivalent —
// same tone vocabulary, so the shared Contract.js output renders identically on
// both sides. Accent and transparency come from the user's settings.
import QtQuick

QtObject {
    id: theme

    // ── user-settable ───────────────────────────────────────────────────────
    /** Accent colour. The eight presets live in SettingsPage. */
    property color accent: "#3daee9"
    /** 0 = fully transparent popup, 1 = solid. */
    property real opacity: 0.94

    // ── base ink ────────────────────────────────────────────────────────────
    readonly property color ink: "#14161b"
    readonly property color inkRaised: "#1b1e25"

    readonly property color background: Qt.rgba(theme.ink.r, theme.ink.g, theme.ink.b, theme.opacity)
    readonly property color surface: Qt.rgba(theme.inkRaised.r, theme.inkRaised.g, theme.inkRaised.b, Math.min(1, theme.opacity + 0.03))
    readonly property color surfaceAlt: Qt.rgba(1, 1, 1, 0.05)

    readonly property color text: "#e8eaf0"
    readonly property color textDim: "#9aa2b4"
    readonly property color textFaint: "#6b7386"
    readonly property color line: Qt.rgba(1, 1, 1, 0.08)
    readonly property color lineStrong: Qt.rgba(1, 1, 1, 0.16)

    // Text that sits on top of a filled accent block.
    readonly property color accentText: theme.luminance(theme.accent) > 0.45 ? "#12141a" : "#ffffff"

    readonly property color positive: "#3fb950"
    readonly property color negative: "#f85149"
    readonly property color neutral: "#d29922"

    // ── metrics ─────────────────────────────────────────────────────────────
    readonly property int radius: 14
    readonly property int radiusSmall: 8
    readonly property int spacing: 8
    readonly property int spacingSmall: 4
    readonly property int shortDuration: 150
    readonly property int longDuration: 250
    readonly property int smallFontSize: 10

    /** Relative luminance, for picking readable text on an arbitrary accent. */
    function luminance(c) {
        function lin(v) {
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    function of(tone) {
        switch (tone) {
        case "positive":
            return theme.positive;
        case "negative":
            return theme.negative;
        case "neutral":
            return theme.neutral;
        case "accent":
            return theme.accent;
        default:
            return theme.textDim;
        }
    }

    /** The same colour at low alpha, for pill and badge backgrounds. */
    function wash(tone, alpha) {
        var c = theme.of(tone);
        return Qt.rgba(c.r, c.g, c.b, alpha === undefined ? 0.16 : alpha);
    }
}
