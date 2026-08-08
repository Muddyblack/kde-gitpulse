// The drawer behind a row's chevron: what it is, then the rarer verbs.
//
// The verbs are contextual — a workflow run offers the pull request that
// triggered it and a re-run; a notification offers unsubscribing. Everything
// offers the repository, because "take me there" is the other thing people
// want from a row and the title alone cannot do it.
import QtQuick
import QtQuick.Layouts

import "../package/contents/code/Format.js" as Format
import "../package/contents/code/GitHub.js" as GH

Rectangle {
    id: drawer

    required property var theme
    required property var item
    required property var engine

    signal openUrl(string url)
    signal done

    readonly property bool isNotification: drawer.item.kind === "notification"
    readonly property bool isRun: drawer.item.kind === "run"
    readonly property int runPull: drawer.isRun && drawer.item.pullNumber ? drawer.item.pullNumber : 0

    implicitHeight: body.implicitHeight + drawer.theme.spacing * 2
    radius: drawer.theme.radiusSmall
    color: drawer.theme.surfaceAlt

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: drawer.theme.spacing
        anchors.leftMargin: drawer.theme.spacing * 2
        spacing: drawer.theme.spacing

        // ── facts ───────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Repeater {
                model: drawer.facts

                delegate: RowLayout {
                    id: fact

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: drawer.theme.spacing * 2

                    Text {
                        text: fact.modelData.key
                        color: drawer.theme.textFaint
                        font.pixelSize: 11
                        font.family: "monospace"
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 52
                    }

                    Text {
                        text: fact.modelData.value
                        color: drawer.theme.textDim
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ── verbs ───────────────────────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: drawer.theme.spacingSmall * 1.5

            ActionButton {
                theme: drawer.theme
                iconName: "external"
                text: qsTr("Open")
                primary: true
                onClicked: {
                    drawer.openUrl(drawer.item.url);
                    drawer.done();
                }
            }

            ActionButton {
                visible: drawer.runPull > 0
                theme: drawer.theme
                iconName: "pull"
                text: qsTr("Pull request #%1").arg(drawer.runPull)
                onClicked: {
                    drawer.openUrl(GH.pullUrl(drawer.item.repo, drawer.runPull));
                    drawer.done();
                }
            }

            ActionButton {
                visible: drawer.isRun
                theme: drawer.theme
                iconName: "refresh"
                text: qsTr("Re-run")
                onClicked: {
                    drawer.engine.rerun(drawer.item);
                    drawer.done();
                }
            }

            ActionButton {
                visible: drawer.isNotification
                theme: drawer.theme
                iconName: "mailRead"
                text: qsTr("Mark read")
                onClicked: {
                    drawer.engine.markRead(drawer.item);
                    drawer.done();
                }
            }

            ActionButton {
                visible: drawer.isNotification
                theme: drawer.theme
                iconName: "bell"
                text: qsTr("Unsubscribe")
                danger: true
                onClicked: {
                    drawer.engine.unsubscribe(drawer.item);
                    drawer.done();
                }
            }

            ActionButton {
                theme: drawer.theme
                iconName: "issue"
                text: qsTr("Repository")
                onClicked: {
                    drawer.openUrl(GH.repoUrl(drawer.item.repo));
                    drawer.done();
                }
            }

            ActionButton {
                theme: drawer.theme
                iconName: "bell"
                text: qsTr("Mute repo")
                danger: true
                onClicked: {
                    drawer.engine.muteRepo(drawer.item.repo);
                    drawer.done();
                }
            }

            ActionButton {
                theme: drawer.theme
                iconName: "external"
                text: qsTr("Copy link")
                onClicked: {
                    clipboard.text = drawer.item.url;
                    clipboard.selectAll();
                    clipboard.copy();
                    drawer.done();
                }
            }
        }
    }

    // QML has no clipboard API; a hidden TextEdit is the standard way in.
    TextEdit {
        id: clipboard

        visible: false
        width: 0
        height: 0
    }

    readonly property var facts: {
        var f = [];
        if (drawer.item.actor)
            f.push({
                key: qsTr("actor"),
                value: drawer.item.actor
            });
        if (drawer.item.reason)
            f.push({
                key: qsTr("reason"),
                value: Format.humanise(drawer.item.reason)
            });
        if (drawer.item.detail)
            f.push({
                key: drawer.isRun ? qsTr("branch") : qsTr("detail"),
                value: drawer.item.detail
            });
        if (drawer.item.raw && drawer.item.raw.display_title && drawer.isRun)
            f.push({
                key: qsTr("job"),
                value: drawer.item.raw.display_title
            });
        f.push({
            key: qsTr("updated"),
            value: qsTr("%1 ago").arg(Format.relative(drawer.item.updatedAt))
        });
        f.push({
            key: qsTr("url"),
            value: String(drawer.item.url).replace("https://", "")
        });
        if (drawer.item.duplicate)
            f.push({
                key: qsTr("note"),
                value: qsTr("also on another tab; counted once")
            });
        return f;
    }
}
