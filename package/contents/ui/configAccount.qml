// Accounts: one card per forge you sign in to, plus what to watch.
//
// The whole list is persisted as one JSON string (`cfg_accounts`) because
// Plasma's kcfg has no list type. A ListModel sits in between rather than a
// plain array: rebuilding an array on every keystroke would recreate the
// delegates and throw away the text field you were typing into.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import "../code/Forge.js" as Forge
import "../code/Http.js" as Http

KCM.SimpleKCM {
    id: page

    property string cfg_accounts: ""
    property alias cfg_repoAllowlist: allowlistField.text
    /** Not aliased to a control: the list below edits this string directly. */
    property string cfg_mutedRepos: ""
    property alias cfg_watchRepoCount: watchCount.value
    property alias cfg_includeOrgRepos: orgReposBox.checked
    property alias cfg_copilotOrg: orgField.text

    /** True once the model has been filled, so loading does not look like editing. */
    property bool loaded: false

    readonly property var providers: Forge.PROVIDERS

    function load() {
        accounts.clear();
        Forge.parse(page.cfg_accounts).forEach(function (a) {
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
        page.cfg_accounts = JSON.stringify(out);
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
        page.set(index, "checkState", "checking");
        var acct = Forge.normalise({
            id: r.accountId,
            provider: r.provider,
            host: r.host,
            token: r.token
        });
        Forge.viewer(acct, function (res) {
            if (res.ok && res.data) {
                page.set(index, "checkState", "ok");
                page.set(index, "checkDetail", res.data.login);
            } else {
                page.set(index, "checkState", "bad");
                page.set(index, "checkDetail", res.error === Http.ERR.AUTH ? i18n("The server rejected this token.") : res.error === Http.ERR.OFFLINE ? i18n("Could not reach %1.", acct.host) : res.error === Http.ERR.NOT_FOUND ? i18n("No API at %1 — is the address right?", acct.host) : (res.message || res.error));
            }
        });
    }

    /** "owner/repo, owner/repo" → ["owner/repo", "owner/repo"], empty entries dropped. */
    readonly property var mutedList: page.cfg_mutedRepos.split(",").map(s => s.trim()).filter(s => s.length > 0)

    function unmute(repo) {
        page.cfg_mutedRepos = page.mutedList.filter(r => r !== repo).join(", ");
    }

    ListModel {
        id: accounts
    }

    Component.onCompleted: page.load()

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: accounts.count === 0
            type: Kirigami.MessageType.Information
            text: i18n("Gitpulse is not signed in anywhere yet. Add a GitHub, GitLab or Codeberg account below — you can add several, and the inbox merges them.")
        }

        Repeater {
            model: accounts

            delegate: Kirigami.AbstractCard {
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
                readonly property var caps: card.descriptor.module.CAPABILITIES

                Layout.fillWidth: true

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    // ── which forge ─────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.ComboBox {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                            model: page.providers.map(function (p) {
                                return p.label;
                            })
                            currentIndex: page.providers.findIndex(p => p.id === card.provider)
                            onActivated: index => {
                                // The host was the old forge's; clearing it
                                // falls back to the new forge's default rather
                                // than pointing GitLab at codeberg.org.
                                page.set(card.index, "host", "");
                                page.set(card.index, "provider", page.providers[index].id);
                                page.set(card.index, "checkState", "");
                            }
                        }

                        QQC2.TextField {
                            Layout.fillWidth: true
                            text: card.label
                            placeholderText: i18n("Name (optional) — “Work”, “Personal”…")
                            onEditingFinished: page.set(card.index, "label", text)
                        }

                        QQC2.ToolButton {
                            icon.name: card.accountEnabled ? "view-visible" : "view-hidden"
                            checkable: true
                            checked: !card.accountEnabled
                            display: QQC2.AbstractButton.IconOnly
                            text: i18n("Pause this account")
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: i18n("Pause this account without deleting its token")
                            onToggled: page.set(card.index, "accountEnabled", !checked)
                        }

                        QQC2.ToolButton {
                            icon.name: "list-remove"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18n("Remove account")
                            onClicked: {
                                accounts.remove(card.index);
                                page.save();
                            }
                        }
                    }

                    // ── where ───────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: i18n("Server:")
                        }

                        QQC2.TextField {
                            Layout.fillWidth: true
                            text: card.host === card.descriptor.defaultHost ? "" : card.host
                            placeholderText: card.descriptor.defaultHost
                            onEditingFinished: {
                                page.set(card.index, "host", text.trim());
                                page.set(card.index, "checkState", "");
                            }
                        }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: card.descriptor.selfHosted
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        text: card.provider === "codeberg" ? i18n("Leave empty for Codeberg. Any Forgejo or Gitea instance works here too — for example %1.", card.descriptor.hostHint) : i18n("Leave empty for the public instance, or point this at a self-hosted one — for example %1.", card.descriptor.hostHint)
                    }

                    // ── credential ──────────────────────────────────────────
                    QQC2.CheckBox {
                        visible: card.descriptor.cli !== ""
                        checked: card.useCli
                        text: i18n("Borrow the GitHub CLI's token (%1)", card.descriptor.cli)
                        onToggled: page.set(card.index, "useCli", checked)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !card.useCli
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.TextField {
                            id: tokenField

                            Layout.fillWidth: true
                            text: card.token
                            echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                            placeholderText: card.descriptor.tokenPlaceholder
                            onTextEdited: {
                                page.set(card.index, "token", text);
                                page.set(card.index, "checkState", "");
                            }
                        }

                        QQC2.ToolButton {
                            id: reveal

                            icon.name: checked ? "password-show-off" : "password-show-on"
                            checkable: true
                            display: QQC2.AbstractButton.IconOnly
                            text: i18n("Show token")
                        }

                        QQC2.Button {
                            text: i18n("Check")
                            enabled: card.token !== "" && card.checkState !== "checking"
                            onClicked: page.verify(card.index)
                        }
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: card.checkState === "ok" || card.checkState === "bad"
                        type: card.checkState === "ok" ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
                        text: card.checkState === "ok" ? i18n("Signed in as %1.", card.checkDetail) : card.checkDetail
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: !card.useCli
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        // Read-only scopes throughout: a leaked Gitpulse token
                        // cannot change anything on any of the three forges.
                        text: i18n("Read-only scopes: %1. Create one at %2", card.descriptor.scopes, Forge.tokenUrl({
                            provider: card.provider,
                            host: card.host
                        }))
                    }

                    // ── GitHub's GraphQL escape hatch ───────────────────────
                    QQC2.TextField {
                        Layout.fillWidth: true
                        visible: card.provider === "github" && !card.useCli
                        text: card.graphqlToken
                        echoMode: TextInput.Password
                        placeholderText: i18n("Profile token (optional) — a classic token with read:user")
                        onTextEdited: page.set(card.index, "graphqlToken", text)
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: card.provider === "github" && !card.useCli
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        text: i18n("Only needed if the Profile tab reports that GraphQL was refused. Fine-grained tokens are excellent for everything else and frequently rejected there.")
                    }

                    // ── what this forge cannot do ───────────────────────────
                    //
                    // Said once, here, instead of leaving an empty tab to be
                    // discovered later.
                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        text: {
                            var missing = [];
                            if (!card.caps.copilot)
                                missing.push(i18n("Copilot"));
                            if (!card.caps.status)
                                missing.push(i18n("service status"));
                            if (!card.caps.rerun)
                                missing.push(i18n("re-running a pipeline"));
                            return missing.length ? i18n("%1 does not offer: %2.", card.descriptor.label, missing.join(", ")) : "";
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("Add account…")
                icon.name: "list-add"
                onClicked: providerMenu.popup()

                QQC2.Menu {
                    id: providerMenu

                    Repeater {
                        model: page.providers

                        delegate: QQC2.MenuItem {
                            required property var modelData

                            text: modelData.label
                            onTriggered: page.addAccount(modelData.id)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ── scope ───────────────────────────────────────────────────────────
        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.SpinBox {
                id: watchCount

                Kirigami.FormData.label: i18n("Watch repositories:")
                from: 1
                to: 25
            }

            QQC2.CheckBox {
                id: orgReposBox

                text: i18n("Include organisation repositories")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Off by default: belonging to one large organisation otherwise fills the Actions tab with pipelines you have never touched.")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                text: i18n("How many of your most recently pushed repositories the Actions tab follows, per account. Each one costs a request per poll.")
            }

            QQC2.TextArea {
                id: allowlistField

                Kirigami.FormData.label: i18n("Only these repositories:")
                placeholderText: i18n("owner/repo, one per line — leave empty for automatic")
                Layout.fillWidth: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                wrapMode: TextEdit.WordWrap
            }

            Item {
                Kirigami.FormData.isSection: true
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Muted repositories:")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                visible: page.mutedList.length === 0
                text: i18n("None. Mute a repository from its row's ⋯ menu in the popup.")
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.mutedList.length > 0
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: page.mutedList

                    delegate: RowLayout {
                        required property string modelData

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: parent.modelData
                            font.family: "monospace"
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        QQC2.Button {
                            text: i18n("Unmute")
                            icon.name: "notifications"
                            onClicked: page.unmute(parent.modelData)
                        }
                    }
                }
            }

            Item {
                Kirigami.FormData.isSection: true
            }

            QQC2.TextField {
                id: orgField

                Kirigami.FormData.label: i18n("Copilot organisation:")
                placeholderText: i18n("optional, needs a GitHub admin token")
                Layout.fillWidth: true
            }
        }
    }
}
