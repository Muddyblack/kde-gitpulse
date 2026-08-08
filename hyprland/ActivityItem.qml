// One row, for every kind of item.
//
// Clicking opens — the rarer verbs sit behind the chevron so the list never
// moves out from under you. Middle-click dismisses without opening, because
// getting rid of noise is as common as reading it.
import QtQuick
import QtQuick.Layouts

import "../package/contents/ui/shared" as Shared
import "../package/contents/code/Format.js" as Format
import "Icons.js" as Glyphs

Rectangle {
    id: row

    required property var item
    required property var theme
    // Optional so this reusable row still renders in isolation.
    property var engine: null
    property bool selected: false
    property bool expanded: false

    signal activated(bool keepOpen)
    signal dismissed
    signal toggleExpanded

    readonly property QuickshellIconAdapter iconAdapter: QuickshellIconAdapter {}
    readonly property bool unread: row.item.unread === true
    readonly property bool running: row.item.running === true
    readonly property bool showActions: hover.hovered || row.selected || row.expanded
    readonly property int pad: row.theme.spacing

    implicitHeight: layout.implicitHeight + row.pad * 2
    radius: row.theme.radiusSmall
    color: hover.hovered ? row.theme.surfaceAlt : "transparent"
    border.width: row.selected ? 1 : 0
    border.color: row.theme.accent

    Behavior on color {
        ColorAnimation {
            duration: row.theme.shortDuration
        }
    }

    // Hover and clicks are tracked separately on purpose.
    //
    // A child MouseArea steals containsMouse from its parent, so using the
    // click area for hover made the row's own buttons vanish the moment the
    // pointer reached them. A HoverHandler is not blocked by children, so it
    // stays true across the whole row.
    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    // Declared before the content so the chevron and open buttons stack above
    // it and consume their own clicks — with a TapHandler here, expanding a row
    // also opened it in the browser.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                row.dismissed();
            else
                row.activated(false);
        }
    }

    // Tone edge — the fastest read in the list: red means a failure without
    // parsing a single word.
    Rectangle {
        width: 3
        radius: 1.5
        color: row.theme.of(row.item.tone)
        opacity: row.unread || row.item.tone !== "muted" ? 1 : 0.35
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        anchors.bottomMargin: 6
    }

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: row.pad
        anchors.leftMargin: row.theme.spacing * 1.75
        anchors.rightMargin: row.theme.spacing
        spacing: row.theme.spacing * 1.25

        // ── who + what ──────────────────────────────────────────────────────
        //
        // The owner's picture carries identity and the corner dot carries
        // state, which is how GitHub's own inbox stays scannable. With no
        // picture the dot grows into the full badge and nothing looks broken.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 28
            implicitHeight: 28

            RoundAvatar {
                anchors.fill: parent
                visible: row.item.avatarUrl !== undefined && row.item.avatarUrl !== ""
                theme: row.theme
                source: row.engine && row.engine.avatarSourceFor ? row.engine.avatarSourceFor(row.item.avatarUrl || "") : row.item.avatarUrl || ""
                login: row.item.repo
            }

            Rectangle {
                id: dot

                readonly property bool solo: !row.item.avatarUrl

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: dot.solo ? 0 : -1
                anchors.bottomMargin: dot.solo ? 0 : -1
                width: dot.solo ? 28 : 15
                height: width
                radius: width / 2
                color: dot.solo ? row.theme.wash(row.item.tone, 0.16) : row.theme.ink
                border.width: dot.solo ? 0 : 1.5
                border.color: row.theme.ink

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: dot.solo ? 0 : 1
                    radius: width / 2
                    color: dot.solo ? "transparent" : row.theme.wash(row.item.tone, 0.9)
                }

                Icon {
                    anchors.centerIn: parent
                    width: dot.solo ? 14 : 9
                    height: width
                    name: Glyphs.forItem(row.item)
                    color: dot.solo ? row.theme.of(row.item.tone) : row.theme.ink
                    spinning: row.running
                }
            }
        }

        // ── body ────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: row.headline
                color: row.theme.text
                font.pixelSize: 13
                font.weight: row.unread ? Font.DemiBold : Font.Normal
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: row.subtitle
                    color: row.theme.textDim
                    font.pixelSize: 11
                    font.family: "monospace"
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: Math.max(60, layout.width * 0.62)
                }

                Shared.Pill {
                    theme: row.theme
                    text: row.item.label
                    tone: row.item.tone
                    iconName: Glyphs.forItem(row.item)
                    spinning: row.running
                    iconDelegate: row.iconAdapter.delegate
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // ── time + hover verbs ──────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 2

            Text {
                text: Format.relative(row.item.updatedAt)
                color: row.theme.textFaint
                font.pixelSize: 11
                font.family: "monospace"
            }

            IconButton {
                theme: row.theme
                iconName: "external"
                tip: qsTr("Open in browser")
                size: 20
                opacity: row.showActions ? 1 : 0
                onClicked: row.activated(true)

                Behavior on opacity {
                    NumberAnimation {
                        duration: row.theme.shortDuration
                    }
                }
            }

            IconButton {
                theme: row.theme
                iconName: "chevron"
                tip: qsTr("More")
                size: 20
                rotation: row.expanded ? 180 : 0
                opacity: row.showActions ? 1 : 0
                onClicked: row.toggleExpanded()

                Behavior on opacity {
                    NumberAnimation {
                        duration: row.theme.shortDuration
                    }
                }
                Behavior on rotation {
                    NumberAnimation {
                        duration: row.theme.longDuration
                    }
                }
            }
        }
    }

    /** "flake-check · nix build .#nixosConfigurations" */
    readonly property string headline: {
        var t = row.item.title || "";
        if (row.item.kind === "run" && row.item.raw && row.item.raw.display_title && row.item.raw.display_title !== t)
            return t + " · " + row.item.raw.display_title;
        return t;
    }

    /** "muddyblack/nixos-config · main" */
    readonly property string subtitle: {
        var bits = [row.item.repo];
        // For a run the branch says more than the run number, and both plus a
        // long repo name elides the repo away to nothing.
        if (row.item.kind === "run")
            bits.push(row.item.detail);
        else if (row.item.number)
            bits.push(row.item.number);
        return bits.filter(function (b) {
            return b;
        }).join(" · ");
    }
}
