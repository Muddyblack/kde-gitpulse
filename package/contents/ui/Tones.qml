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

    /**
     * The system accent by default — including Plasma 6's accent-from-wallpaper
     * — with an opt-in override for people who want this one widget to differ.
     */
    readonly property color accent: Plasmoid.configuration.accentMode === "custom" && Plasmoid.configuration.customAccent !== "" ? Plasmoid.configuration.customAccent : Kirigami.Theme.highlightColor

    /** Readable text on top of a filled accent block, whichever accent it is. */
    readonly property color accentText: {
        function lin(v) {
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        }
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
