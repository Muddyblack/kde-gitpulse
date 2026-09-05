// Compact diff statistics badge for pull requests: +additions / -deletions.
//
// Platform-neutral — plain QtQuick only, driven by `theme`.
import QtQuick
import QtQuick.Layouts

import "../../code/Format.js" as Fmt

RowLayout {
    id: diff

    required property var theme
    property var additions: null
    property var deletions: null

    readonly property bool hasDiff: diff.additions !== null && diff.additions !== undefined && diff.deletions !== null && diff.deletions !== undefined

    visible: hasDiff
    spacing: 3

    Text {
        text: Fmt.diffAdditions(diff.additions)
        color: diff.theme.of("positive")
        font.pixelSize: diff.theme.smallFontSize ? Math.max(9, Math.round(diff.theme.smallFontSize * 0.95)) : 10
        font.family: "monospace"
        font.weight: Font.DemiBold
    }

    Text {
        text: Fmt.diffDeletions(diff.deletions)
        color: diff.theme.of("negative")
        font.pixelSize: diff.theme.smallFontSize ? Math.max(9, Math.round(diff.theme.smallFontSize * 0.95)) : 10
        font.family: "monospace"
        font.weight: Font.DemiBold
    }
}
