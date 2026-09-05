// One row, for every kind of item.
//
// Clicking opens — deliberately unlike a stock ExpandableListItem, where a
// click expands. Opening is what people came to do; the rarer actions are one
// chevron away and never move the list out from under you.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "shared" as Shared
import "../code/Forge.js" as Forge
import "../code/Format.js" as Fmt

Item {
    id: row

    required property var item
    required property var engine
    property bool selected: false
    property bool expanded: false

    signal activated(bool keepOpen)
    signal focusRequested
    signal toggleExpanded
    signal openUrlRequested(string url)

    readonly property Tones tones: Tones {}
    readonly property KirigamiIconAdapter iconAdapter: KirigamiIconAdapter {}
    readonly property bool unread: row.item.unread === true
    readonly property bool hasDiff: row.item.additions !== null && row.item.additions !== undefined && row.item.deletions !== null && row.item.deletions !== undefined

    implicitHeight: layout.implicitHeight

    Accessible.role: Accessible.Button
    Accessible.name: row.item.title
    Accessible.description: i18nc("repository, state and age", "%1 · %2 · %3", row.item.repo, row.item.label, Fmt.since(row.item.updatedAt))

    // Rounded hover/selection card instead of the stock square Highlight —
    // mirrors hyprland/ActivityItem.qml's rows so the list reads the same on
    // both platforms.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Kirigami.Units.smallSpacing / 2)
        radius: Kirigami.Units.cornerRadius
        color: mouse.containsMouse || row.selected ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, row.selected ? 0.14 : 0.08) : "transparent"
        border.width: row.selected ? 1 : 0
        border.color: Qt.rgba(row.tones.accent.r, row.tones.accent.g, row.tones.accent.b, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    // Unread marker: an accent edge, never colour alone — the title is also
    // bolder, so this survives both a colour-blind reader and a mono theme.
    Rectangle {
        visible: row.unread
        width: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
        radius: width / 2
        color: row.tones.accent
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onEntered: row.focusRequested()
        onClicked: mouseEvent => {
            // Middle-click dismisses without opening: getting rid of noise is
            // as common as reading it.
            if (mouseEvent.button === Qt.MiddleButton) {
                row.engine.markRead(row.item);
            } else {
                row.activated((mouseEvent.modifiers & Qt.ControlModifier) !== 0);
            }
        }
    }

    ColumnLayout {
        id: layout

        width: parent.width
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 1.5

            // Tone circle carrying the kind/reason glyph.
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                radius: width / 2
                color: row.tones.wash(row.item.tone, 0.16)

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                    height: width
                    source: row.item.icon
                    color: row.tones.of(row.item.tone)
                    isMask: true

                    RotationAnimator on rotation {
                        running: row.item.running === true
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: Kirigami.Units.veryLongDuration * 3
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                // Whatever the meta line below ends up carrying, this column is
                // the part that gives way. Without a floor of zero its children
                // set the row's minimum width, and anything that does not fit
                // shoves the time and the More-actions chevron out of view
                // instead of eliding.
                Layout.minimumWidth: 0
                spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: row.item.title
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.weight: row.unread ? Font.DemiBold : Font.Normal
                    opacity: row.item.tone === "muted" && !row.unread ? 0.75 : 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    // Which forge this came from. Absent with one account
                    // configured, because then it is not telling you anything.
                    PlasmaComponents.Label {
                        visible: row.engine && row.engine.liveAccounts.length > 1
                        text: Forge.shortName(row.item.provider)
                        font.family: "monospace"
                        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.82)
                        font.weight: Font.DemiBold
                        color: Kirigami.Theme.disabledTextColor
                        opacity: 0.8
                    }

                    PlasmaComponents.Label {
                        text: row.item.repo + (row.item.number ? " " + row.item.number : "")
                        font.family: "monospace"
                        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.92)
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideMiddle
                        // Against the row's own width, not the layout's: a
                        // RowLayout's width is derived from its children, so
                        // constraining a child by `parent.width` here made the
                        // layout depend on itself ("recursive rearrange").
                        // The repo is the one thing here that can lose
                        // characters and still be read, so it yields the space
                        // a diff badge needs rather than the time and chevron
                        // being pushed off the right edge.
                        Layout.maximumWidth: row.width * (row.hasDiff ? 0.32 : 0.45)
                    }

                    Shared.Pill {
                        theme: row.tones
                        text: row.item.label
                        tone: row.item.tone
                        iconName: row.item.icon
                        iconDelegate: row.iconAdapter.delegate
                    }

                    Shared.DiffStat {
                        theme: row.tones
                        additions: row.item.additions
                        deletions: row.item.deletions
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 0

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignRight
                    text: Fmt.relative(row.item.updatedAt)
                    font.family: "monospace"
                    font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.9)
                    color: Kirigami.Theme.disabledTextColor
                }

                PlasmaComponents.ToolButton {
                    Layout.alignment: Qt.AlignRight
                    icon.name: "expand"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("More actions")
                    flat: true
                    opacity: mouse.containsMouse || row.selected || row.expanded ? 1 : 0
                    rotation: row.expanded ? 180 : 0
                    onClicked: row.toggleExpanded()

                    PlasmaComponents.ToolTip.text: i18n("More actions  ( Space )")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                    Behavior on rotation {
                        NumberAnimation {
                            duration: Kirigami.Units.longDuration
                        }
                    }
                }
            }
        }

        RowActions {
            item: row.item
            engine: row.engine
            visible: row.expanded
            Layout.fillWidth: true
            onOpenRequested: row.activated(true)
            onOpenUrlRequested: url => row.openUrlRequested(url)
            onDone: row.toggleExpanded()
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            opacity: 0.5
        }
    }
}
