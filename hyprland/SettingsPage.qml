// Token, sources and appearance for the Quickshell frontend.
//
// Writes straight into the JSON the shell persists; there is no config dialog
// to hand off to the way Plasma has one.
import QtQuick
import QtQuick.Controls.Basic as QC
import QtQuick.Dialogs
import QtQuick.Layouts

import "../package/contents/code/Forge.js" as Forge
import "../package/contents/code/Http.js" as Http

QC.ScrollView {
    id: page

    required property var theme
    required property var settings
    /** "", "probing", "ok", "unauthenticated" — surfaced by the shell. */
    property string ghState: ""

    signal closed

    readonly property var providerIds: Forge.PROVIDERS.map(p => p.id)
    /** True once the model has been filled, so loading does not look like editing. */
    property bool loaded: false

    readonly property var swatches: ["#3daee9", "#9b59b6", "#27ae60", "#f67400", "#da4453", "#e93a9a", "#16a085", "#7aa2f7"]

    ListModel {
        id: accounts
    }

    function load() {
        accounts.clear();
        Forge.parse(page.settings.accounts).forEach(function (a) {
            accounts.append({
                accountId: a.id,
                provider: a.provider,
                host: a.host,
                token: a.token,
                graphqlToken: a.graphqlToken,
                label: a.label,
                useCli: a.useCli,
                accountEnabled: a.enabled,
                checkState: "",
                checkDetail: ""
            });
        });
        page.loaded = true;
    }

    function save() {
        if (!page.loaded)
            return;
        var out = [];
        for (var i = 0; i < accounts.count; i++) {
            var r = accounts.get(i);
            out.push({
                id: r.accountId,
                provider: r.provider,
                host: r.host,
                token: r.token,
                graphqlToken: r.graphqlToken,
                label: r.label,
                useCli: r.useCli,
                enabled: r.accountEnabled
            });
        }
        page.settings.accounts = JSON.stringify(out);
    }

    function set(index, key, value) {
        accounts.setProperty(index, key, value);
        if (key !== "checkState" && key !== "checkDetail")
            page.save();
    }

    function addAccount(providerId) {
        var a = Forge.blank(providerId);
        accounts.append({
            accountId: a.id,
            provider: a.provider,
            host: "",
            token: "",
            graphqlToken: "",
            label: "",
            useCli: false,
            accountEnabled: true,
            checkState: "",
            checkDetail: ""
        });
        page.save();
    }

    /** Ask the forge who this token belongs to, and say so plainly. */
    function verify(index) {
        var r = accounts.get(index);
        if (r.token === "")
            return;
        page.set(index, "checkState", "checking");
        var acct = Forge.normalise({
            id: r.accountId,
            provider: r.provider,
            host: r.host,
            token: r.token
        });
        Forge.viewer(acct, function (res) {
            page.set(index, "checkState", res.ok ? "ok" : "bad");
            page.set(index, "checkDetail", res.ok && res.data ? res.data.login : res.error === Http.ERR.OFFLINE ? qsTr("Could not reach %1").arg(acct.host) : (res.message || res.error));
        });
    }

    Component.onCompleted: page.load()

    contentWidth: availableWidth
    clip: true

    component Field: Rectangle {
        id: field

        property string value: ""
        property string placeholder: ""
        property bool secret: false

        signal edited(string value)

        implicitHeight: 30
        radius: page.theme.radiusSmall
        color: Qt.rgba(0, 0, 0, 0.25)
        border.width: 1
        border.color: input.activeFocus ? page.theme.accent : page.theme.line

        QC.TextField {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            // Bound one way only: writing back on every keystroke would fight
            // the model update and drop characters.
            text: field.value
            echoMode: field.secret ? TextInput.Password : TextInput.Normal
            placeholderText: field.placeholder
            color: page.theme.text
            placeholderTextColor: page.theme.textFaint
            font.pixelSize: 12
            background: null
            onTextEdited: field.edited(text)
        }
    }

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

        // ══ accounts ════════════════════════════════════════════════════════
        //
        // The same JSON the Plasma side writes, edited through a ListModel so
        // a keystroke does not rebuild — and unfocus — the field being typed
        // into.
        Caption {
            Layout.fillWidth: true
            visible: accounts.count === 0
            text: qsTr("Not signed in anywhere yet. Add a GitHub, GitLab or Codeberg account — you can add several, and the inbox merges them.")
        }

        Repeater {
            model: accounts

            delegate: Rectangle {
                id: card

                required property int index
                required property string accountId
                required property string provider
                required property string host
                required property string token
                required property string graphqlToken
                required property string label
                required property bool useCli
                required property bool accountEnabled
                required property string checkState
                required property string checkDetail

                readonly property var descriptor: Forge.descriptor(card.provider)

                Layout.fillWidth: true
                implicitHeight: cardBody.implicitHeight + page.theme.spacing * 2
                radius: page.theme.radiusSmall
                color: page.theme.surfaceAlt
                border.width: 1
                border.color: page.theme.line
                opacity: card.accountEnabled ? 1 : 0.55

                ColumnLayout {
                    id: cardBody

                    x: page.theme.spacing
                    y: page.theme.spacing
                    width: card.width - page.theme.spacing * 2
                    spacing: page.theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.theme.spacingSmall

                        // A three-way cycle rather than a combo box: Basic
                        // controls have no styled popup, and three forges do
                        // not need one.
                        ActionButton {
                            theme: page.theme
                            text: card.descriptor.label
                            primary: true
                            onClicked: {
                                var i = page.providerIds.indexOf(card.provider);
                                var next = page.providerIds[(i + 1) % page.providerIds.length];
                                page.set(card.index, "host", "");
                                page.set(card.index, "provider", next);
                                page.set(card.index, "checkState", "");
                            }
                        }

                        Field {
                            Layout.fillWidth: true
                            value: card.label
                            placeholder: qsTr("Name (optional)")
                            onEdited: v => page.set(card.index, "label", v)
                        }

                        ActionButton {
                            theme: page.theme
                            iconName: card.accountEnabled ? "eye" : "eye-off"
                            text: card.accountEnabled ? qsTr("Pause") : qsTr("Resume")
                            onClicked: page.set(card.index, "accountEnabled", !card.accountEnabled)
                        }

                        ActionButton {
                            theme: page.theme
                            iconName: "x"
                            text: qsTr("Remove")
                            onClicked: {
                                accounts.remove(card.index);
                                page.save();
                            }
                        }
                    }

                    Field {
                        Layout.fillWidth: true
                        value: card.host === card.descriptor.defaultHost ? "" : card.host
                        placeholder: card.descriptor.defaultHost
                        onEdited: v => {
                            page.set(card.index, "host", v.trim());
                            page.set(card.index, "checkState", "");
                        }
                    }

                    Toggle {
                        Layout.fillWidth: true
                        visible: card.descriptor.cli !== ""
                        text: qsTr("Borrow the GitHub CLI's token (gh auth token)")
                        checked: card.useCli
                        onToggled: v => page.set(card.index, "useCli", v)
                    }

                    Caption {
                        Layout.fillWidth: true
                        visible: card.useCli
                        text: page.ghState === "ok" ? qsTr("Borrowed the token gh already stores. Nothing new was created.") : page.ghState === "missing" ? qsTr("gh is not on PATH — install the GitHub CLI, or paste a token instead.") : page.ghState === "unauthenticated" ? qsTr("gh is installed but returned no token — run “gh auth login”.") : qsTr("Asking gh for its token…")
                        color: page.ghState === "ok" ? page.theme.positive : (page.ghState === "missing" || page.ghState === "unauthenticated") ? page.theme.negative : page.theme.textFaint
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !card.useCli
                        spacing: page.theme.spacingSmall

                        Field {
                            Layout.fillWidth: true
                            value: card.token
                            secret: true
                            placeholder: card.descriptor.tokenPlaceholder
                            onEdited: v => {
                                page.set(card.index, "token", v);
                                page.set(card.index, "checkState", "");
                            }
                        }

                        ActionButton {
                            theme: page.theme
                            iconName: "refresh"
                            text: qsTr("Check")
                            onClicked: page.verify(card.index)
                        }
                    }

                    Caption {
                        Layout.fillWidth: true
                        visible: card.checkState === "ok" || card.checkState === "bad"
                        text: card.checkState === "ok" ? qsTr("Signed in as %1").arg(card.checkDetail) : card.checkDetail
                        color: card.checkState === "ok" ? page.theme.positive : page.theme.negative
                    }

                    Caption {
                        Layout.fillWidth: true
                        visible: !card.useCli
                        text: qsTr("Read-only scopes: %1").arg(card.descriptor.scopes)
                    }

                    Field {
                        Layout.fillWidth: true
                        visible: card.provider === "github" && !card.useCli
                        value: card.graphqlToken
                        secret: true
                        placeholder: qsTr("Profile token (optional) — classic, read:user")
                        onEdited: v => page.set(card.index, "graphqlToken", v)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: page.theme.spacingSmall

            Repeater {
                model: page.providerIds

                delegate: ActionButton {
                    required property string modelData

                    theme: page.theme
                    iconName: "plus"
                    text: qsTr("Add %1").arg(Forge.descriptor(modelData).label)
                    onClicked: page.addAccount(modelData)
                }
            }

            Item {
                Layout.fillWidth: true
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
