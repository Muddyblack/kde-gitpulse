// The one place a semantic tone becomes a colour.
//
// Contract.js only ever emits tone names; nothing in the UI hard-codes a hex
// value, so the widget follows the user's colour scheme and Plasma 6 accent
// (including accent-from-wallpaper) for free.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

QtObject {
    id: tones

    readonly property color positive: Kirigami.Theme.positiveTextColor
    readonly property color negative: Kirigami.Theme.negativeTextColor
    readonly property color neutral: Kirigami.Theme.neutralTextColor
    readonly property color muted: Kirigami.Theme.disabledTextColor

    // ── the rest of the shared theme contract ──────────────────────────────
    //
    // hyprland/Theme.qml's shape, so this doubles as the `theme` object every
    // package/contents/ui/shared/*.qml component expects — one interface,
    // two implementations, instead of the components themselves forking.
    readonly property color textDim: Kirigami.Theme.disabledTextColor
    readonly property color textFaint: Qt.rgba(Kirigami.Theme.disabledTextColor.r, Kirigami.Theme.disabledTextColor.g, Kirigami.Theme.disabledTextColor.b, 0.7)
    readonly property int spacing: Kirigami.Units.smallSpacing
    readonly property int spacingSmall: Math.round(Kirigami.Units.smallSpacing / 2)
    readonly property int shortDuration: Kirigami.Units.shortDuration
    readonly property int longDuration: Kirigami.Units.longDuration
    /** Baseline for small chrome text (pills, captions) — tracks the user's
     *  actual font/DPI scale, unlike a component hardcoding a raw pixel size. */
    readonly property int smallFontSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.88)

    /**
     * The system accent by default — including Plasma 6's accent-from-wallpaper
     * — with an opt-in override for people who want this one widget to differ.
     */
    readonly property color accent: Plasmoid.configuration.accentMode === "custom" && Plasmoid.configuration.customAccent !== "" ? Plasmoid.configuration.customAccent : Kirigami.Theme.highlightColor

    /** Readable text on top of a filled accent block, whichever accent it is. */
    readonly property color accentText: {
        var lin = function (v) {
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        };
        var l = 0.2126 * lin(tones.accent.r) + 0.7152 * lin(tones.accent.g) + 0.0722 * lin(tones.accent.b);
        return l > 0.45 ? Qt.rgba(0.07, 0.08, 0.1, 1) : Qt.rgba(1, 1, 1, 1);
    }

    function of(tone) {
        switch (tone) {
        case "positive":
            return tones.positive;
        case "negative":
            return tones.negative;
        case "neutral":
            return tones.neutral;
        case "accent":
            return tones.accent;
        default:
            return tones.muted;
        }
    }

    /** Same colour at low alpha, for pill and icon-circle backgrounds. */
    function wash(tone, alpha) {
        var c = tones.of(tone);
        return Qt.rgba(c.r, c.g, c.b, alpha === undefined ? 0.15 : alpha);
    }
}
