// The drawer behind a row's chevron: details, then the rarer verbs.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

import "../code/Contract.js" as Contract
import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

ColumnLayout {
    id: drawer

    required property var item
    required property var engine

    signal openRequested
    signal openUrlRequested(string url)
    signal done

    // Cards stay legible on every surface: opaque on "solid", but letting the
    // blurred/tinted popup show through on "translucent"/"glass" — otherwise
    // this drawer is the one solid block left floating on a frosted popup.
    readonly property real cardAlpha: {
        switch (Plasmoid.configuration.surfaceMode) {
        case "glass":
            return Plasmoid.configuration.popupOpacity;
        case "translucent":
            return 0.3;
        default:
            return 1;
        }
    }

    readonly property bool isNotification: drawer.item.kind === Contract.KIND.NOTIFICATION
    readonly property bool isRun: drawer.item.kind === Contract.KIND.RUN
    readonly property int runPull: drawer.isRun && drawer.item.pullNumber ? drawer.item.pullNumber : 0

    spacing: Kirigami.Units.smallSpacing

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: inner.implicitHeight + Kirigami.Units.smallSpacing * 2
        color: Qt.rgba(Kirigami.Theme.alternateBackgroundColor.r, Kirigami.Theme.alternateBackgroundColor.g, Kirigami.Theme.alternateBackgroundColor.b, drawer.cardAlpha)

        ColumnLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            anchors.leftMargin: Kirigami.Units.gridUnit * 2
            spacing: Kirigami.Units.smallSpacing

            // ── details ─────────────────────────────────────────────────────
            Repeater {
                model: drawer.details

                delegate: RowLayout {
                    required property var modelData

                    spacing: Kirigami.Units.smallSpacing * 2
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: parent.modelData.key
                        font.family: "monospace"
                        font.pixelSize: Math.round(Kirigami.Theme.smallFont.pixelSize * 0.9)
                        color: Kirigami.Theme.disabledTextColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                    }

                    PlasmaComponents.Label {
                        text: parent.modelData.value
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ── verbs ───────────────────────────────────────────────────────
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    icon.name: "internet-services"
                    text: i18n("Open")
                    onClicked: drawer.openRequested()
                }

                PlasmaComponents.Button {
                    visible: drawer.isNotification
                    icon.name: "mail-mark-read"
                    text: i18n("Mark read")
                    enabled: drawer.item.unread === true
                    onClicked: {
                        drawer.engine.markRead(drawer.item);
                        drawer.done();
                    }
                }

                PlasmaComponents.Button {
                    visible: drawer.isNotification
                    icon.name: "notifications-disabled"
                    text: i18n("Unsubscribe")
                    onClicked: {
                        drawer.engine.unsubscribe(drawer.item);
                        drawer.done();
                    }

                    PlasmaComponents.ToolTip.text: i18n("Stop receiving notifications for this thread")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.Button {
                    visible: drawer.runPull > 0
                    icon.name: "vcs-merge-request"
                    text: i18n("Pull request #%1", drawer.runPull)
                    onClicked: {
                        drawer.openUrlRequested(GH.pullUrl(drawer.item.repo, drawer.runPull));
                        drawer.done();
                    }

                    PlasmaComponents.ToolTip.text: i18n("Open the pull request this run belongs to")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.Button {
                    visible: drawer.isRun
                    icon.name: "view-refresh"
                    text: i18n("Re-run")
                    onClicked: {
                        drawer.engine.rerun(drawer.item);
                        drawer.done();
                    }
                }

                PlasmaComponents.Button {
                    icon.name: "folder-git"
                    text: i18n("Repository")
                    onClicked: {
                        drawer.openUrlRequested(GH.repoUrl(drawer.item.repo));
                        drawer.done();
                    }
                }

                PlasmaComponents.Button {
                    icon.name: "notifications-disabled"
                    text: i18n("Mute repo")
                    onClicked: {
                        drawer.engine.muteRepo(drawer.item.repo);
                        drawer.done();
                    }

                    PlasmaComponents.ToolTip.text: i18n("Hide everything from %1 until you unmute it in settings", drawer.item.repo)
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents.Button {
                    icon.name: "edit-copy"
                    text: i18n("Copy link")
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
        // It lives inside the Rectangle so no layout tries to manage it.
        TextEdit {
            id: clipboard

            visible: false
            width: 0
            height: 0
        }
    }

    readonly property var details: {
        var d = [];
        if (drawer.item.actor)
            d.push({
                key: i18n("actor"),
                value: drawer.item.actor
            });
        if (drawer.item.reason)
            d.push({
                key: i18n("reason"),
                value: Fmt.humanise(drawer.item.reason)
            });
        if (drawer.item.detail)
            d.push({
                key: i18n("detail"),
                value: drawer.item.detail
            });
        d.push({
            key: i18n("updated"),
            value: i18n("%1 ago", Fmt.relative(drawer.item.updatedAt))
        });
        if (drawer.item.duplicate)
            d.push({
                key: i18n("note"),
                value: i18n("also shown on another tab; counted once")
            });
        return d;
    }
}
