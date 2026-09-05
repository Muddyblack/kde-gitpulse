[h1]Gitpulse[/h1]

Gitpulse is a KDE Plasma 6 System Tray widget that keeps the work that needs
your attention in your panel — from GitHub, GitLab and Codeberg at the same
time. Review requests, mentions, assignments, failing pipelines, pull requests,
issues, profile activity, Copilot health and GitHub service status are one
click away.

---

[b]Features[/b]
[list]
[*] [b]Every Forge, One Inbox:[/b] GitHub, GitLab and Codeberg side by side —
public instances, GitHub Enterprise Server, a self-hosted GitLab, or any
Forgejo or Gitea server. Add as many accounts as you like; one badge counts
them all, and each row shows which forge it came from.
[*] [b]Actionable Inbox:[/b] See unread notifications, mentions, team mentions,
assignments, review requests and security alerts. Open or mark them read
directly from the popup.
[*] [b]A Meaningful Tray Badge:[/b] The count represents work blocking on you,
rather than every unread GitHub notification. Related inbox and pull-request
entries are counted only once.
[*] [b]Actions at a Glance:[/b] Inspect recent workflow runs for repositories
you pushed to, with failed runs surfaced first.
[*] [b]Pull Requests and Issues:[/b] Review requests, your own pull requests,
and issues you are involved in stay grouped and easy to scan.
[*] [b]Profile View:[/b] Account statistics, a contribution graph, a 24-hour
commit dial showing when in the day you actually work, streak figures and your
language mix — all in your Plasma accent colour.
[*] [b]Quiet Hours:[/b] Set a window and Gitpulse stops interrupting inside it.
The badge and the lists keep updating, so nothing is missed — it just does not
interrupt.
[*] [b]Service Health:[/b] GitHub Status components, recent incidents and
Copilot service health are available without opening a browser.
[*] [b]Plasma-native:[/b] Uses the System Tray, desktop notifications, theme
colours and your GitHub avatar when signed in. Middle-click the tray icon to
refresh; use the scroll wheel to switch tabs.
[*] [b]Keyboard Friendly:[/b] Filter, switch tabs, open or dismiss items,
refresh, and assign a global shortcut from the widget settings.
[/list]

---

[b]Installation[/b]

Via KDE Store: right-click a panel, select [i]Add Widgets[/i] → [i]Get New
Widgets[/i] → [i]Download New Plasma Widgets[/i], then search for
[b]Gitpulse[/b].

To install a release archive manually:
[code]
kpackagetool6 --type Plasma/Applet --install gitpulse-VERSION.plasmoid
[/code]

Then add Gitpulse from [i]Add Widgets[/i], or place it in the System Tray.

To install from source:
[code]
git clone https://github.com/Muddyblack/kde-gitpulse.git
cd gitpulse
make install
[/code]

---

[b]GitHub Token[/b]

Gitpulse only reads GitHub data. Create a personal access token in GitHub's
[i]Settings[/i] → [i]Developer settings[/i] → [i]Personal access tokens[/i],
then add it in Gitpulse's [b]Account[/b] settings page.

A classic token can use these read scopes:
[list]
[*] [b]notifications[/b] — Inbox
[*] [b]repo[/b] — private repositories and their Actions runs
[*] [b]read:org[/b] — organisation repositories
[*] [b]read:user[/b] — contribution graph
[/list]

Fine-grained tokens work for the other views, but GitHub does not allow them
to read the contribution graph. The widget handles that limitation gracefully.
The token is kept in the widget's own Plasma configuration file.

---

[b]Requirements[/b]
[list]
[*] KDE Plasma 6.0 or later
[*] A GitHub account and personal access token for account-specific data
[*] Internet access to GitHub
[/list]

GitHub Status and Copilot service-health information can be shown without a
token.
