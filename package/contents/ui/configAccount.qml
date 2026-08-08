// Token entry, with a live check so nobody has to guess whether it worked.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

import "../code/GitHub.js" as GH

KCM.SimpleKCM {
    id: page

    property alias cfg_token: tokenField.text
    property alias cfg_graphqlToken: graphField.text
    property alias cfg_useGhCli: ghBox.checked
    property alias cfg_repoAllowlist: allowlistField.text
    /** Not aliased to a control: the list below edits this string directly. */
    property string cfg_mutedRepos: ""
    property alias cfg_watchRepoCount: watchCount.value
    property alias cfg_includeOrgRepos: orgReposBox.checked
    property alias cfg_copilotOrg: orgField.text

    property string checkState: "" // "", "checking", "ok", "bad"
    property string checkDetail: ""

    function verify() {
        if (tokenField.text === "")
            return;
        page.checkState = "checking";
        GH.viewer(tokenField.text, function (res) {
            if (res.ok && res.data) {
                page.checkState = "ok";
                page.checkDetail = res.data.login;
            } else {
                page.checkState = "bad";
                page.checkDetail = res.error === GH.ERR.AUTH ? i18n("GitHub rejected this token.") : res.error === GH.ERR.OFFLINE ? i18n("No network connection.") : (res.message || res.error);
            }
        });
    }

    /** "owner/repo, owner/repo" → ["owner/repo", "owner/repo"], empty entries dropped. */
    readonly property var mutedList: page.cfg_mutedRepos.split(",").map(s => s.trim()).filter(s => s.length > 0)

    function unmute(repo) {
        page.cfg_mutedRepos = page.mutedList.filter(r => r !== repo).join(", ");
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: ghBox

            Kirigami.FormData.label: i18n("Credential:")
            text: i18n("Borrow the GitHub CLI's token (gh auth token)")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            visible: ghBox.checked
            text: i18n("Uses the credential gh already stores — nothing new is created. Note that gh's default scopes omit read:user, so the contribution graph may still want its own token below; “gh auth refresh -s read:user” fixes that.")
        }

        RowLayout {
            visible: !ghBox.checked
            Kirigami.FormData.label: i18n("Token:")

            QQC2.TextField {
                id: tokenField

                echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                placeholderText: i18n("ghp_… or github_pat_…")
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                onTextChanged: page.checkState = ""
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
                enabled: tokenField.text !== "" && page.checkState !== "checking"
                onClicked: page.verify()
            }
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: false
            Layout.fillWidth: true
            visible: page.checkState !== "" && page.checkState !== "checking"
            type: page.checkState === "ok" ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
            text: page.checkState === "ok" ? i18n("Signed in as %1.", page.checkDetail) : page.checkDetail
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            text: i18n("Gitpulse only ever reads. A classic token needs <b>notifications</b>, <b>repo</b> (read), <b>read:org</b> and <b>read:user</b>; the last one is what makes the Profile tab's contribution graph possible. The token is stored in this widget's own configuration file under your home directory.")
            textFormat: Text.RichText
        }

        QQC2.TextField {
            id: graphField

            Kirigami.FormData.label: i18n("Profile token:")
            echoMode: TextInput.Password
            placeholderText: i18n("optional — leave empty to reuse the token above")
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Only needed if the Profile tab reports that GraphQL was refused. Fine-grained tokens are excellent for everything else and frequently rejected there, so a classic token with read:user can be given to that one tab.")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        // ── scope ───────────────────────────────────────────────────────────
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
            text: i18n("How many of your most recently pushed repositories the Actions tab follows. Each one costs a request per poll.")
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
            placeholderText: i18n("optional, needs an admin token")
            Layout.fillWidth: true
        }
    }
}
