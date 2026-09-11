<p align="center">
  <img src="./package/icon.png" width="96" alt="Gitpulse icon">
</p>

<h1 align="center">Gitpulse</h1>

<p align="center">
  <a href="https://www.opendesktop.org/p/2368081/">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store Download" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  </a>
  <a href="https://www.opendesktop.org/p/2368081/">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%2F%3Fformat%3Djson%26user%3DMuddyblack%26pagesize%3D20%26sortmode%3Dalpha%26search%3Dgitpulse&query=%24.data%5B0%5D.downloads&label=KDE%20Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
  </a>
  <a href="https://github.com/Muddyblack/kde-gitpulse/releases">
    <img src="https://img.shields.io/github/downloads/Muddyblack/kde-gitpulse/total?style=for-the-badge&logo=github&logoColor=white&label=GitHub%20Downloads&color=blue" alt="GitHub Downloads" />
  </a>
</p>

<p align="center"><strong>The pulse of your repos, in your panel.</strong></p>

<p align="center">
  Notifications, CI runs, pull requests, issues, your profile and service health —<br>
  from <strong>GitHub</strong>, <strong>GitLab</strong> and <strong>Codeberg</strong>, in one panel,<br>
  as a native <strong>KDE Plasma 6</strong> widget or <strong>Hyprland / Quickshell</strong> panel.
</p>

<p align="center">
  <img src="readme/panel.svg" width="264" alt="Gitpulse in a desktop panel">
</p>

> Built for KDE Plasma 6 and Hyprland / Quickshell, with one shared core.

## At a glance

| Native to your desktop | Every forge you use | Knows what needs you |
| --- | --- | --- |
| One shared core, with a Plasma plasmoid and Hyprland / Quickshell frontend. | GitHub, GitLab and Codeberg side by side — public or self-hosted, as many accounts as you like. | The badge counts things blocking **you**, not every unread notification. |

## A closer look

| Inbox | Actions |
| --- | --- |
| <img src="readme/demo_inbox.svg" alt="Gitpulse inbox tab" width="440"> | <img src="readme/demo_actions.svg" alt="Gitpulse Actions tab" width="440"> |
| Review requests, mentions, assignments and an honest unread workflow. | Recent workflow runs, with failures first. |

| Profile | GitHub status |
| --- | --- |
| <img src="readme/demo_profile.svg" alt="Gitpulse profile tab" width="440"> | <img src="readme/demo_status.svg" alt="Gitpulse status tab" width="440"> |
| Contribution activity, language mix and account stats. | Component health and 90-day incident-derived strips. |

## At home in your desktop

Gitpulse is available as a **KDE Plasma 6** plasmoid and a **Hyprland /
Quickshell** panel. It uses the desktop notification system, follows your
Plasma theme and accent colour, and uses your avatar as the tray icon when
signed in.

## Every forge, one inbox

| | Inbox | Pulls & issues | Pipelines | Profile |
| --- | :-: | :-: | :-: | :-: |
| **GitHub** — github.com or Enterprise Server | notifications | ✓ | Actions | full, incl. heatmap |
| **GitLab** — gitlab.com or self-hosted | todos | merge requests | pipelines | heatmap + dial |
| **Codeberg** — or any Forgejo / Gitea instance | notifications | ✓ | Forgejo Actions | heatmap + dial |

Add as many accounts as you like, on any mix of the three. Items from every
account land in the same lists, sorted together, counted by one badge — and
cross-tab de-duplication is scoped per account, so `owner/repo#1` on two
different forges stays two different things.

A forge that does not have a feature says so in its account card rather than
leaving an empty tab to be discovered later: Copilot and the GitHub service
status page are GitHub-only, and Forgejo has no API for re-running a workflow.

## Everything in the popup

| Tab | What it shows |
| --- | --- |
| **Inbox** | Unread notifications, with a "new since you last looked" divider |
| **Actions** | Workflow runs across your recently-pushed repos, failures first |
| **Pulls** | Pull requests awaiting your review, and your own |
| **Issues** | Issues you are involved in, assignment highlighted |
| **Profile** | Stats, a contribution heatmap in your accent colour, an hour-of-day commit dial, language mix |
| **Copilot** | Copilot service health and billed usage |
| **Status** | GitHub service health with a 90-day incident strip per component |

### The badge means one thing

The tray count is **"someone is blocked on you"**, not "unread". It counts
unread review requests, mentions, team mentions, assignments and security
alerts, plus failing runs on your branches and PRs awaiting your review. An
open issue on your plate is tracked but never inflates it.

Cross-tab de-duplication means a `review_requested` notification and the pull
request behind it count **once** — the inbox wins, because that is where the
action lives.

GitLab and Codeberg do not send GitHub's `reason` field, so their providers map
their own signals onto the same vocabulary: a GitLab `review_requested` todo
and a Forgejo pull-request notification reach the badge for exactly the same
reason a GitHub one does.

### Quiet hours

Set a window in **Behaviour** and Gitpulse stops interrupting inside it. The
badge and every list keep updating — only the desktop notification is withheld,
so the count is right the moment you next look at the panel.

---

## Install

### NixOS (flake)

```nix
{
  inputs.gitpulse.url = "github:Muddyblack/kde-gitpulse";

  # KDE: the plasmoid
  environment.systemPackages = [ inputs.gitpulse.packages.${system}.default ];

  # Hyprland: tray + shell
  # nix run github:Muddyblack/kde-gitpulse#hyprland
}
```

### Any distribution, from source

```sh
git clone https://github.com/Muddyblack/kde-gitpulse
cd gitpulse
make install          # copies into ~/.local/share/plasma/plasmoids and restarts plasmashell
```

`NO_RESTART=1 make install` skips the `plasmashell` restart.

### As a `.plasmoid` archive

```sh
make pack             # writes gitpulse-<version>.plasmoid
kpackagetool6 --type Plasma/Applet --install gitpulse-0.1.0.plasmoid
```

Then add it from **Add Widgets…**, or drop it into the System Tray — the
package declares `X-Plasma-NotificationArea`, so it is offered there.

---

## Accounts

Gitpulse only ever reads. Open the widget's **Accounts** page, press
**Add account…**, pick the forge, paste a token and press **Check** — it tells
you immediately whether the server accepted it and who it signed you in as.

Leave **Server** empty for the public instance, or point it at a self-hosted
one. GitHub Enterprise Server, a private GitLab and any Forgejo or Gitea
instance all work through the same three providers.

| Forge | Create a token at | Scopes |
| --- | --- | --- |
| **GitHub** | Settings ▸ Developer settings ▸ Personal access tokens | `notifications`, `repo` (read), `read:org`, `read:user` |
| **GitLab** | Preferences ▸ Access tokens | `read_api`, `read_user` |
| **Codeberg / Forgejo** | Settings ▸ Applications | `read:notification`, `read:repository`, `read:issue`, `read:user` |

On GitHub you can skip the token entirely and tick **Borrow the GitHub CLI's
token** — Gitpulse then reads whatever `gh auth token` already stores and
creates nothing of its own.

Fine-grained GitHub tokens work for everything except the contribution
heatmap: GitHub's GraphQL `contributionsCollection` is not available to them.
Give that one account a classic **Profile token** with `read:user`, or let the
Profile tab degrade to stats-without-heatmap — it says which, rather than
failing whole.

Tokens are stored in the widget's own config file under `$XDG_CONFIG_HOME`,
which is not world-readable. On the Hyprland side that is
`$XDG_CONFIG_HOME/gitpulse/hyprland-settings.json`, written atomically and
listed in `.gitignore`.

Upgrading from 1.x needs no action: the single GitHub token you had becomes
your first account the first time the widget starts.

### Rate limit

Defaults poll the inbox every 60 s, searches every 180 s and Actions every
300 s — roughly 170 of GitHub's 5000 requests per hour, worst case, per
account. Every GET carries its previous `ETag`, and GitHub does not count a
`304` against the limit, so the real figure is usually far lower. The Sources settings page shows
the estimate live as you change the intervals, and the popup footer shows what
is actually left.

---

## Hyprland

```sh
nix run github:Muddyblack/kde-gitpulse#hyprland
```

Or manually, from a checkout:

```sh
cmake -S hyprland/tray -B build && cmake --build build
./build/gitpulse-tray "$(command -v qs)" "$PWD/shell.qml" \
  "$PWD/package/contents/icons/org.muddyblack.gitpulse.svg" &
qs -p "$PWD/shell.qml"
```

Point `qs` at **`shell.qml` in the repository root**, never at the file in
`hyprland/`. Quickshell roots its QML sandbox at the entry point's directory,
and the Hyprland frontend imports the same `Engine.qml` and JS the Plasma
widget uses from `package/contents/` — rooted at `hyprland/`, those imports
escape the sandbox and nothing loads.

The popup starts hidden. Click the tray icon, or drive it directly:

```sh
qs ipc -p "$PWD/shell.qml" call panel toggle
```

`show`, `hide`, `refresh`, `badge`, `summary` and `quit` are also available —
the tray helper uses `badge` and `summary` to paint itself rather than keeping
a second copy of your token.

All seven tabs are present on this side too. Only Copilot is off by default,
since most accounts have nothing to report there.

---

## Keyboard

Everything below works whenever the popup is open; press <kbd>?</kbd> for the
same list in the widget.

| Key | Action |
| --- | --- |
| <kbd>↑</kbd> <kbd>↓</kbd> | move through the list |
| <kbd>Enter</kbd> | open, mark read, close |
| <kbd>Ctrl</kbd>+<kbd>Enter</kbd> | open in the background |
| <kbd>Space</kbd> | expand inline actions |
| <kbd>M</kbd> | mark read |
| <kbd>Shift</kbd>+<kbd>M</kbd> | mark all read (undoable) |
| <kbd>/</kbd> | filter |
| <kbd>Alt</kbd>+<kbd>1…9</kbd> | jump to a tab |
| <kbd>G</kbd> | group by repository |
| <kbd>R</kbd> | refresh now |
| <kbd>Esc</kbd> | clear filter, then close |

Mouse: left-click a row opens it, middle-click dismisses it without opening,
and the chevron expands the actions. On the tray icon, middle-click refreshes
and the scroll wheel cycles tabs. A global shortcut can be assigned in the
widget's own **Keyboard Shortcuts** config page.

### Undo

"Mark all read" waits six seconds behind an undo toast before it contacts
GitHub. That is not decoration: the REST API has no *mark unread*, so the only
honest undo is one where the request has not been sent yet. The window is
configurable, and zero sends immediately.

---

## What this cannot do

Stated plainly, because the alternative is inventing numbers:

- **Per-user Copilot statistics do not exist in the public API.** Completion
  counts and acceptance rates are organisation- and enterprise-admin endpoints.
  The Copilot tab therefore shows service health (which needs no token at all),
  billed usage when your token can read the billing endpoint, and organisation
  metrics if you configure an org you administer.
- **The 90-day strips are incident-derived.** githubstatus.com publishes
  current component status and an incident feed, but not the per-component
  uptime series behind the bars on its own site. Gitpulse builds its strips
  from the incident feed and labels them "incident-free days" — not an uptime
  percentage, because it is not one.
- **Contribution heatmaps need a classic token on GitHub** (see above). GitLab
  and Forgejo publish theirs to any read token.
- **The hour dial is a shape, not a census.** On GitHub it is real
  `committedDate` timestamps from the repositories you have pushed to recently,
  and it falls back to the public event feed when the token cannot do GraphQL —
  which is public activity only. On GitLab and Forgejo it comes from the
  activity feed those forges already expose. In every case it answers "when do
  I work", not "how much have I ever done".

---

## Development

```sh
nix develop          # qmllint, qmlformat, qml, plasma-sdk, pre-commit
make help            # list targets
make test            # unit tests, engine smoke test, and both UIs rendered
make shots           # PNG per tab for both frontends, into build/shots
make lint            # qmllint every QML file
make format          # qmlformat in place
make view            # preview the widget standalone
make install         # install into the running Plasma session
```

### Layout

```
package/contents/
  code/       Http.js        — transport, caching, one error vocabulary
              Contract.js    — the item shape, badge arithmetic, calendars
              GitHub.js      — GitHub / GHES endpoints + normalisation
              GitLab.js      — GitLab endpoints + normalisation
              Forgejo.js     — Codeberg / Forgejo / Gitea, same
              Forge.js       — the registry: accounts in, a provider out
              Format.js      — presentation helpers
  ui/         Engine.qml + the Plasma UI
  ui/shared/  QtQuick-only components both frontends use unchanged
  config/     main.xml (kcfg) + the config dialog pages
hyprland/     Quickshell frontend, reusing code/ and Engine.qml unchanged
  tray/       Qt Widgets StatusNotifier binary that drives it over qs ipc
tests/        run-tests.qml     — pure logic, every provider
              engine-smoke.qml  — the engine actually runs
              hyprland-smoke.qml / plasma-smoke.qml — both UIs render
              stubs/            — stand-in Plasma modules for the Plasma test
```

The dependency graph is a straight line: `Http.js` knows about HTTP and
nothing else, `Contract.js` owns the one item shape every forge collapses into,
each provider turns its own JSON into that shape, and `Forge.js` picks the
provider for an account. `Engine.qml` talks only to `Forge.js`, so **adding a
fourth forge is a new module plus a row in `PROVIDERS`** — not a change to the
engine, the badge arithmetic or either frontend.

Everything under `code/` is a `.pragma library` script with no QML
dependencies, which is why `tests/run-tests.qml` can exercise it directly —
286 assertions against the exact code that ships, in the exact engine it ships
on.

### What the tests actually verify

`tests/ApiSamples.js` holds recorded API payloads, and the provider tests run
the normalisers over them. This matters because the rest of the suite only
proves the providers are self-consistent — it cannot tell you whether a field
is spelled the way the forge spells it.

| Forge | How the samples were obtained | Verified |
| --- | --- | --- |
| GitHub | unchanged since 1.x, in daily use | by use |
| GitLab | captured live from gitlab.com's public endpoints | pipelines, projects, languages, the event feed and `calendar.json` |
| Codeberg / Forgejo | built field-for-field from Gitea's published swagger, which Forgejo shares | every endpoint path, every query parameter, every field read |

Not verified: the authenticated endpoints on GitLab and Codeberg — todos,
notifications, the issue search and the account's own identity call. Those need
a real token against a real server, which no test in this repository has. If
you hit something there, it is worth an issue.

### Both frontends are rendered in CI

`make test` runs four things: the unit suite (286 assertions), an engine smoke test that proves
the bindings evaluate and the timers stay off when they should, and then
**both** UIs rendered offscreen through every tab and state. Any `TypeError`,
`ReferenceError` or layout recursion fails the build.

The Plasma run uses the stand-in Kirigami and PlasmaComponents in
`tests/stubs/` (see its README), so it works on a machine with no Plasma
installed. `make shots` writes a PNG per tab for both frontends into `build/shots`
(`gitpulse-plasma-*.png` and `gitpulse-hyprland-*.png`) — handy for a pull
request, and for spotting a layout that collapsed without opening a session.

## Licence

MIT — see [LICENSE](LICENSE).
