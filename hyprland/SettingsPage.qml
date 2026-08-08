// Token, sources and appearance for the Quickshell frontend.
//
// Writes straight into the JSON the shell persists; there is no config dialog
// to hand off to the way Plasma has one.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Dialogs
import QtQuick.Layouts

import "../package/contents/code/GitHub.js" as GH

QC.ScrollView {
    id: page

    required property var theme
    required property var settings
    /** "", "probing", "ok", "unauthenticated" — surfaced by the shell. */
    property string ghState: ""

    signal closed

    property string checkState: ""
    property string checkDetail: ""

    readonly property var swatches: ["#3daee9", "#9b59b6", "#27ae60", "#f67400", "#da4453", "#e93a9a", "#16a085", "#7aa2f7"]

    function verify() {
        if (page.settings.token === "")
            return;
        page.checkState = "checking";
        GH.viewer(page.settings.token, function (res) {
            page.checkState = res.ok ? "ok" : "bad";
            page.checkDetail = res.ok && res.data ? res.data.login : (res.message || res.error);
        });
    }

    contentWidth: availableWidth
    clip: true

    component Caption: Text {
        color: page.theme.textFaint
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }

    component Toggle: Item {
        id: box

        property string text: ""
        property bool checked: false

        signal toggled(bool value)

        implicitHeight: 24
        implicitWidth: parent ? parent.width : 200

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 4
                color: box.checked ? page.theme.accent : "transparent"
                border.width: 1
                border.color: box.checked ? page.theme.accent : page.theme.lineStrong

                Icon {
                    anchors.centerIn: parent
                    width: 11
                    height: 11
                    visible: box.checked
                    name: "check"
                    color: page.theme.accentText
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: box.text
                color: page.theme.text
                font.pixelSize: 12
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: box.toggled(!box.checked)
        }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: page.theme.spacing

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: qsTr("Settings")
                color: page.theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            ActionButton {
                theme: page.theme
                iconName: "check"
                text: qsTr("Done")
                primary: true
                onClicked: page.closed()
            }
        }

        // ══ credentials ═════════════════════════════════════════════════════
        Toggle {
            Layout.fillWidth: true
            text: qsTr("Use the GitHub CLI's token (gh auth token)")
            checked: page.settings.useGhCli
            onToggled: v => page.settings.useGhCli = v
        }

        Caption {
            Layout.fillWidth: true
            visible: page.settings.useGhCli
            text: page.ghState === "ok" ? qsTr("Borrowed the token gh already stores. Nothing new was created.") : page.ghState === "missing" ? qsTr("gh is not on PATH — install the GitHub CLI, or paste a token instead.") : page.ghState === "unauthenticated" ? qsTr("gh is installed but returned no token — run “gh auth login”.") : qsTr("Asking gh for its token…")
            color: page.ghState === "ok" ? page.theme.positive : (page.ghState === "missing" || page.ghState === "unauthenticated") ? page.theme.negative : page.theme.textFaint
        }

        Caption {
            Layout.fillWidth: true
            visible: !page.settings.useGhCli
            text: qsTr("GitHub token — read-only scopes: notifications, repo, read:org, read:user")
        }

        RowLayout {
            visible: !page.settings.useGhCli
            Layout.fillWidth: true
            spacing: page.theme.spacingSmall

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: page.theme.radiusSmall
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: tokenField.activeFocus ? page.theme.accent : page.theme.line

                QC.TextField {
                    id: tokenField

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: page.settings.token
                    echoMode: TextInput.Password
                    placeholderText: "ghp_…"
                    color: page.theme.text
                    placeholderTextColor: page.theme.textFaint
                    font.pixelSize: 12
                    background: null
                    onTextChanged: {
                        page.checkState = "";
                        page.settings.token = text;
                    }
                }
            }

            ActionButton {
                theme: page.theme
                iconName: "refresh"
                text: qsTr("Check")
                onClicked: page.verify()
            }
        }

        Caption {
            Layout.fillWidth: true
            visible: page.checkState === "ok" || page.checkState === "bad"
            text: page.checkState === "ok" ? qsTr("Signed in as %1").arg(page.checkDetail) : page.checkDetail
            color: page.checkState === "ok" ? page.theme.positive : page.theme.negative
        }

        // ══ graphql token ═══════════════════════════════════════════════════
        Caption {
            Layout.fillWidth: true
            text: qsTr("Profile token (optional) — a classic token with read:user. Only needed if the Profile tab reports that GraphQL was refused; fine-grained tokens often are.")
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: page.theme.radiusSmall
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: graphField.activeFocus ? page.theme.accent : page.theme.line

            QC.TextField {
                id: graphField

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: page.settings.graphqlToken
                echoMode: TextInput.Password
                placeholderText: qsTr("leave empty to reuse the token above")
                color: page.theme.text
                placeholderTextColor: page.theme.textFaint
                font.pixelSize: 12
                background: null
                onTextChanged: page.settings.graphqlToken = text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: page.theme.line
        }

        // ══ appearance ══════════════════════════════════════════════════════
        Caption {
            text: qsTr("Accent")
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: page.swatches

                delegate: Rectangle {
                    id: swatch

                    required property string modelData

                    width: 24
                    height: 24
                    radius: 12
                    color: swatch.modelData
                    border.width: page.settings.accent === swatch.modelData ? 2 : 0
                    border.color: page.theme.text

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: page.settings.accent = swatch.modelData
                    }

                    Behavior on border.width {
                        NumberAnimation {
                            duration: page.theme.shortDuration
                        }
                    }
                }
            }

            // The full picker, for anything the presets do not cover.
            Rectangle {
                width: 92
                height: 24
                radius: page.theme.radiusSmall
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: page.theme.line

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        height: 13
                        radius: 3
                        color: page.settings.accent
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Custom…")
                        color: page.theme.text
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        accentDialog.selectedColor = page.settings.accent;
                        accentDialog.open();
                    }
                }
            }
        }

        ColorDialog {
            id: accentDialog

            title: qsTr("Gitpulse accent colour")
            onAccepted: page.settings.accent = selectedColor.toString()
        }

        Toggle {
            Layout.fillWidth: true
            Layout.topMargin: page.theme.spacingSmall
            text: qsTr("Glass surface")
            checked: page.settings.glass
            onToggled: v => page.settings.glass = v
        }

        Caption {
            Layout.fillWidth: true
            visible: page.settings.glass
            text: qsTr("Add “layerrule = blur, quickshell” to hyprland.conf for the frosted look; without it the panel is simply translucent.")
        }

        Caption {
            Layout.topMargin: page.theme.spacingSmall
            text: qsTr("Background opacity — %1%").arg(Math.round(page.settings.backgroundOpacity * 100))
        }

        QC.Slider {
            id: opacitySlider

            Layout.fillWidth: true
            from: 0.35
            to: 1
            value: page.settings.backgroundOpacity
            onMoved: page.settings.backgroundOpacity = value

            background: Rectangle {
                x: opacitySlider.leftPadding
                y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                width: opacitySlider.availableWidth
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: opacitySlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: page.theme.accent
                }
            }

            handle: Rectangle {
                x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: 7
                color: page.theme.accent
                border.width: 2
                border.color: page.theme.ink
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: page.theme.line
        }

        // ══ sources ═════════════════════════════════════════════════════════
        Caption {
            text: qsTr("Sources")
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("Actions — workflow runs")
            checked: page.settings.actionsEnabled
            onToggled: v => page.settings.actionsEnabled = v
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("Pull requests")
            checked: page.settings.pullsEnabled
            onToggled: v => page.settings.pullsEnabled = v
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("Issues")
            checked: page.settings.issuesEnabled
            onToggled: v => page.settings.issuesEnabled = v
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("Profile — stats and contribution graph")
            checked: page.settings.profileEnabled
            onToggled: v => page.settings.profileEnabled = v
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("Copilot")
            checked: page.settings.copilotEnabled
            onToggled: v => page.settings.copilotEnabled = v
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("GitHub service status")
            checked: page.settings.statusEnabled
            onToggled: v => page.settings.statusEnabled = v
        }

        Toggle {
            Layout.fillWidth: true
            text: qsTr("Only threads I participate in")
            checked: page.settings.participatingOnly
            onToggled: v => page.settings.participatingOnly = v
        }

        // ══ muted ═══════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: page.theme.spacingSmall
            implicitHeight: 1
            color: page.theme.line
            visible: String(page.settings.mutedRepos).trim() !== ""
        }

        Caption {
            visible: String(page.settings.mutedRepos).trim() !== ""
            text: qsTr("Muted repositories")
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: String(page.settings.mutedRepos).split(",").map(s => s.trim()).filter(s => s.length)

                delegate: Chip {
                    id: muted

                    required property string modelData

                    theme: page.theme
                    text: muted.modelData
                    onClicked: {
                        var list = String(page.settings.mutedRepos).split(",").map(s => s.trim()).filter(s => s.length && s !== muted.modelData);
                        page.settings.mutedRepos = list.join(", ");
                    }
                }
            }
        }

        Caption {
            visible: String(page.settings.mutedRepos).trim() !== ""
            text: qsTr("Click one to unmute it.")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
