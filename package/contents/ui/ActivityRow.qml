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

    implicitHeight: layout.implicitHeight

    Accessible.role: Accessible.Button
    Accessible.name: row.item.title
    Accessible.description: i18nc("repository, state and age", "%1 · %2 · %3 ago", row.item.repo, row.item.label, Fmt.relative(row.item.updatedAt))

    // Rounded hover/selection card instead of the stock square Highlight —
    // mirrors hyprland/ActivityItem.qml's rows so the list reads the same on
    // both platforms.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Kirigami.Units.smallSpacing / 2)
        radius: Kirigami.Units.cornerRadius
        color: mouse.containsMouse || row.selected ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, row.selected ? 0.16 : 0.08) : "transparent"
        border.width: row.selected ? 1 : 0
        border.color: row.tones.accent

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

                    PlasmaComponents.Label {
                        text: row.item.repo + (row.item.number ? " " + row.item.number : "")
                        font.family: "monospace"
                        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.92)
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: parent.width * 0.55
                    }

                    Shared.Pill {
                        theme: row.tones
                        text: row.item.label
                        tone: row.item.tone
                        iconName: row.item.icon
                        iconDelegate: row.iconAdapter.delegate
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
