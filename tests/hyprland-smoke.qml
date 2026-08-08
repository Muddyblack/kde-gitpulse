// Gitpulse — Quickshell UI smoke test.
//
//   qml -platform offscreen tests/hyprland-smoke.qml     (or: make test)
//
// Renders the whole Hyprland popup with fabricated data and cycles every tab
// and both row states. Every pane here is plain QtQuick, so none of it needs a
// running compositor — only GitpulseShell.qml itself pulls in Quickshell.
//
// The point is to surface binding errors (TypeError, ReferenceError, "Unable
// to assign") in CI instead of in someone's session. The runner greps stderr,
// so anything QML complains about fails the build.
import QtQuick
import "../hyprland" as H
import "../package/contents/ui" as Core
import "../package/contents/code/Contract.js" as Contract

Item {
    id: harness

    width: 440
    height: 620

    readonly property var tabs: [
        {
            id: "inbox",
            label: "Inbox"
        },
        {
            id: "actions",
            label: "Actions"
        },
        {
            id: "pulls",
            label: "Pulls"
        },
        {
            id: "issues",
            label: "Issues"
        },
        {
            id: "profile",
            label: "Profile"
        },
        {
            id: "copilot",
            label: "Copilot"
        },
        {
            id: "status",
            label: "Status"
        }
    ]

    property int step: 0

    /**
     * Pass `--shot <dir>` to also write a PNG per tab. Handy for eyeballing a
     * change without a compositor, and for attaching to a pull request.
     */
    readonly property string shotDir: {
        var a = Qt.application.arguments;
        var i = a.indexOf("--shot");
        return i >= 0 && i + 1 < a.length ? a[i + 1] : "";
    }

    function shoot(label) {
        if (harness.shotDir === "")
            return;
        harness.grabToImage(function (result) {
            result.saveToFile(harness.shotDir + "/gitpulse-" + label + ".png");
        });
    }

    H.Theme {
        id: ui
    }

    // The real shell paints this; without it the translucent surfaces composite
    // onto white and every screenshot comes out washed out.
    Rectangle {
        anchors.fill: parent
        color: ui.ink
    }

    Core.Engine {
        id: core

        // Nothing may touch the network during a test run.
        statusEnabled: false
        profileEnabled: false
        copilotEnabled: false
        actionsEnabled: false
        pullsEnabled: false
        issuesEnabled: false
    }

    H.PopupChrome {
        id: chrome

        anchors.fill: parent
        theme: ui
        engine: core
        tabs: harness.tabs
        currentTab: "inbox"
        settingsVisible: false
    }

    H.SettingsPage {
        anchors.fill: parent
        visible: false
        theme: ui
        settings: fakeSettings
    }

    QtObject {
        id: fakeSettings

        property string token: ""
        property string graphqlToken: ""
        property bool useGhCli: false
        property bool actionsEnabled: true
        property bool pullsEnabled: true
        property bool issuesEnabled: true
        property bool profileEnabled: true
        property bool copilotEnabled: false
        property bool statusEnabled: true
        property bool participatingOnly: false
        property string mutedRepos: "muddyblack/noisy"
        property string accent: "#3daee9"
        property real backgroundOpacity: 0.85
        property bool glass: true
    }

    function fabricate() {
        var now = Date.now();
        function iso(minAgo) {
            return new Date(now - minAgo * 60000).toISOString();
        }

        var inbox = [Contract.notification({
                id: "1",
                unread: true,
                reason: "review_requested",
                updated_at: iso(4),
                repository: {
                    full_name: "muddyblack/gitpulse"
                },
                subject: {
                    title: "Review requested: popup tab order",
                    type: "PullRequest",
                    url: "https://api.github.com/repos/muddyblack/gitpulse/pulls/14"
                }
            }), Contract.notification({
                id: "2",
                unread: true,
                reason: "mention",
                updated_at: iso(52),
                repository: {
                    full_name: "muddyblack/ai-usage-widget"
                },
                subject: {
                    title: "@muddyblack can you confirm the path?",
                    type: "Issue",
                    url: "https://api.github.com/repos/muddyblack/ai-usage-widget/issues/42"
                }
            }), Contract.notification({
                id: "3",
                unread: false,
                reason: "state_change",
                updated_at: iso(1500),
                repository: {
                    full_name: "muddyblack/dotfiles"
                },
                subject: {
                    title: "PR merged: waybar cleanup",
                    type: "PullRequest",
                    url: "https://api.github.com/repos/muddyblack/dotfiles/pulls/5"
                }
            })];

        var actions = [Contract.run({
                id: 11,
                name: "flake-check",
                display_title: "nix build .#nixosConfigurations",
                status: "completed",
                conclusion: "failure",
                head_branch: "main",
                run_number: 42,
                updated_at: iso(26),
                actor: {
                    login: "muddyblack"
                },
                _repo: "muddyblack/nixos-config"
            }, "muddyblack"), Contract.run({
                id: 12,
                name: "build-plasmoid",
                display_title: "package",
                status: "in_progress",
                head_branch: "feat/actions-tab",
                updated_at: iso(2),
                pull_requests: [
                    {
                        number: 12
                    }
                ],
                actor: {
                    login: "muddyblack"
                },
                _repo: "muddyblack/gitpulse"
            }, "muddyblack"), Contract.run({
                id: 13,
                name: "tests",
                status: "completed",
                conclusion: "success",
                head_branch: "main",
                updated_at: iso(180),
                actor: {
                    login: "muddyblack"
                },
                _repo: "muddyblack/ai-usage-widget"
            }, "muddyblack")];

        var pulls = [Contract.searchItem({
                id: 21,
                number: 58,
                title: "Fix interpreter resolution",
                state: "open",
                updated_at: iso(60),
                html_url: "https://github.com/o/r/pull/58",
                repository_url: "https://api.github.com/repos/muddyblack/ai-usage-widget",
                url: "https://api.github.com/repos/muddyblack/ai-usage-widget/issues/58",
                user: {
                    login: "kdeuser"
                },
                assignees: [],
                pull_request: {
                    url: "https://api.github.com/repos/muddyblack/ai-usage-widget/pulls/58"
                }
            }, "muddyblack")];
        pulls[0].reviewRequested = true;

        var issues = [Contract.searchItem({
                id: 31,
                number: 9,
                title: "Badge count wrong when every section is empty",
                state: "open",
                updated_at: iso(180),
                html_url: "https://github.com/o/r/issues/9",
                repository_url: "https://api.github.com/repos/muddyblack/gitpulse",
                url: "https://api.github.com/repos/muddyblack/gitpulse/issues/9",
                user: {
                    login: "muddyblack"
                },
                assignees: [
                    {
                        login: "muddyblack"
                    }
                ],
                labels: [
                    {
                        name: "bug"
                    }
                ]
            }, "muddyblack")];

        var sections = {
            inbox: inbox,
            actions: actions,
            pulls: pulls,
            issues: issues
        };
        core.badge = Contract.badge(sections);
        core.sections = sections;
        core.everLoaded = true;
        core.lastUpdateMs = now - 12000;
        core.rateLimit = 5000;
        core.rateRemaining = 4870;
        core.viewer = {
            login: "muddyblack",
            avatar_url: ""
        };

        // The Status and Profile panes read these directly.
        core.statusComponents = [
            {
                id: "git",
                name: "Git Operations",
                status: "operational",
                tone: "positive"
            },
            {
                id: "actions",
                name: "Actions",
                status: "degraded_performance",
                tone: "neutral"
            }
        ];
        core.copilotComponents = [
            {
                id: "cop",
                name: "Copilot",
                status: "operational",
                tone: "positive"
            }
        ];
        core.incidents = [
            {
                impact: "major",
                created_at: new Date(now - 3 * 86400000).toISOString(),
                resolved_at: new Date(now - 3 * 86400000 + 7200000).toISOString(),
                status: "resolved",
                updated_at: new Date(now - 3 * 86400000).toISOString(),
                name: "Elevated errors",
                components: [
                    {
                        id: "actions"
                    }
                ]
            }
        ];
        core.statusSummary = {
            status: {
                indicator: "minor",
                description: "Partially degraded service"
            },
            components: []
        };
        core.profile = Contract.profile({
            login: "muddyblack",
            name: "Muddyblack",
            bio: "information should be free",
            createdAt: "2016-01-01T00:00:00Z",
            followers: {
                totalCount: 76
            },
            following: {
                totalCount: 18
            },
            gists: {
                totalCount: 0
            },
            organizations: {
                totalCount: 5
            },
            sponsors: {
                totalCount: 0
            },
            starredRepositories: {
                totalCount: 139
            },
            repositories: {
                totalCount: 62,
                nodes: [
                    {
                        nameWithOwner: "muddyblack/a",
                        stargazerCount: 139,
                        languages: {
                            edges: [
                                {
                                    size: 800,
                                    node: {
                                        name: "QML",
                                        color: "#44a51c"
                                    }
                                }
                            ]
                        }
                    }
                ]
            },
            contributionsCollection: {
                totalCommitContributions: 22,
                totalIssueContributions: 23,
                totalPullRequestContributions: 58,
                totalPullRequestReviewContributions: 12,
                restrictedContributionsCount: 4,
                contributionCalendar: {
                    totalContributions: 1860,
                    weeks: [
                        {
                            contributionDays: [
                                {
                                    date: "2026-01-01",
                                    contributionCount: 0,
                                    weekday: 0
                                },
                                {
                                    date: "2026-01-02",
                                    contributionCount: 5,
                                    weekday: 1
                                }
                            ]
                        }
                    ]
                }
            }
        });
        // A full year, so the heatmap, the 30-day trend and the streak card all
        // get something shaped like real data instead of two lonely cells.
        var weeks = [];
        var seed = 7;
        for (var w = 0; w < 52; w++) {
            var days = [];
            for (var d = 0; d < 7; d++) {
                seed = (seed * 1103515245 + 12345) % 2147483648;
                var r = seed / 2147483648;
                var count = d === 0 || d === 6 ? Math.floor(r * 4) : Math.floor(r * r * 18);
                days.push({
                    date: "2026-" + ("0" + (1 + w % 12)).slice(-2) + "-" + ("0" + (1 + d)).slice(-2),
                    contributionCount: count,
                    weekday: d
                });
            }
            weeks.push({
                contributionDays: days
            });
        }
        core.calendar = Contract.calendar({
            contributionCalendar: {
                totalContributions: 1293,
                weeks: weeks
            }
        });

        var events = [];
        [9, 9, 10, 11, 11, 13, 14, 16, 19, 20, 20, 21, 22, 2].forEach(function (h) {
            events.push({
                created_at: new Date(2026, 0, 5, h, 0, 0).toISOString()
            });
        });
        core.rhythm = Contract.rhythm(events);
        core.languages = [
            {
                name: "QML",
                share: 70,
                color: "#44a51c"
            },
            {
                name: "Other",
                share: 30,
                color: ""
            }
        ];
        core.copilot = {
            quantity: 1420,
            included: 300,
            netAmount: 4.5,
            skus: [
                {
                    name: "premium_request",
                    quantity: 1420
                }
            ]
        };
    }

    Component.onCompleted: harness.fabricate()

    /** Every state worth rendering, in order. */
    readonly property var states: [
        {
            label: "inbox",
            apply: () => chrome.currentTab = "inbox"
        },
        {
            label: "actions",
            apply: () => chrome.currentTab = "actions"
        },
        {
            label: "pulls",
            apply: () => chrome.currentTab = "pulls"
        },
        {
            label: "issues",
            apply: () => chrome.currentTab = "issues"
        },
        {
            label: "profile",
            apply: () => chrome.currentTab = "profile"
        },
        {
            label: "copilot",
            apply: () => chrome.currentTab = "copilot"
        },
        {
            label: "status",
            apply: () => chrome.currentTab = "status"
        },
        {
            label: "inbox-expanded",
            apply: () => {
                chrome.currentTab = "inbox";
                chrome.expandedId = core.sections.inbox[0].id;
            }
        },
        {
            label: "actions-expanded",
            apply: () => {
                chrome.currentTab = "actions";
                chrome.expandedId = core.sections.actions[1].id;   // the running one
            }
        },
        {
            label: "search",
            apply: () => {
                chrome.expandedId = "";
                chrome.currentTab = "inbox";
                chrome.searchActive = true;
                chrome.query = "review";
            }
        },
        {
            label: "grouped",
            apply: () => {
                chrome.query = "";
                chrome.searchActive = false;
                chrome.grouped = true;
            }
        },
        {
            label: "chip-filtered",
            apply: () => {
                chrome.grouped = false;
                chrome.currentTab = "actions";
                chrome.setChip("failed");
            }
        }
    ]

    // Two ticks per state: one to apply and render it, one to grab it.
    // grabToImage is asynchronous, so grabbing and mutating in the same tick
    // captures the state that comes next.
    Timer {
        interval: 90
        repeat: true
        running: true

        property bool pendingGrab: false

        onTriggered: {
            if (pendingGrab) {
                harness.shoot(harness.states[harness.step].label);
                pendingGrab = false;
                harness.step++;
                return;
            }
            if (harness.step >= harness.states.length) {
                console.warn("hyprland-smoke: rendered every tab and state");
                Qt.exit(0);
                return;
            }
            harness.states[harness.step].apply();
            pendingGrab = true;
        }
    }
}
