// Gitpulse — the fixtures both smoke tests render.
//
// One set of fabricated items, two frontends. When this drifted between
// tests/hyprland-smoke.qml and its Plasma counterpart, the two screenshots
// stopped being comparable and a regression could hide in whichever set was
// thinner. There is one copy now.
//
// Nothing here touches the network: the engine is put to sleep first, and the
// bootstrap that would otherwise fetch identities is cancelled the moment it
// is armed.
.pragma library

.import "../package/contents/code/Contract.js" as Contract
.import "../package/contents/code/GitHub.js" as GH
.import "../package/contents/code/Forgejo.js" as FJ
.import "../package/contents/code/Forge.js" as Forge

/**
 * Two accounts on two forges, so the account strip and the per-item forge
 * marks are exercised rather than assumed.
 */
function accounts() {
    return [Forge.normalise({
        id: "gh",
        provider: "github",
        token: "x",
        login: "muddyblack"
    }), Forge.normalise({
        id: "cb",
        provider: "codeberg",
        token: "x",
        login: "muddyblack"
    })];
}

/** Fill `core` (the shared Engine singleton) with a plausible day's worth. */
function install(core) {
    var accts = accounts();
    var ACC = accts[0];
    var CB = accts[1];


    // Nothing may touch the network during a test run: `active` stops
    // every timer, and the debounce that would otherwise bootstrap the
    // accounts below is cancelled the moment it is armed.
    core.active = false;
    core.accountsJson = Forge.stringify([ACC, CB]);
    core._restartTimer.stop();
    core.identities = {
        gh: {
            login: "muddyblack",
            name: "Muddyblack",
            avatarUrl: ""
        },
        cb: {
            login: "muddyblack",
            name: "Muddyblack",
            avatarUrl: ""
        }
    };
    core.statusEnabled = false;
    core.profileEnabled = false;
    core.copilotEnabled = false;
    core.actionsEnabled = false;
    core.pullsEnabled = false;
    core.issuesEnabled = false;

    var now = Date.now();
    function iso(minAgo) {
        return new Date(now - minAgo * 60000).toISOString();
    }

    var inbox = [GH.notification(ACC, {
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
        }), GH.notification(ACC, {
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
        }), GH.notification(ACC, {
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
        }), FJ.notification(CB, {
            id: 4,
            unread: true,
            updated_at: iso(11),
            repository: {
                full_name: "muddyblack/forgejo-thing"
            },
            subject: {
                title: "Review requested: drop the vendored copy",
                type: "Pull",
                html_url: "https://codeberg.org/muddyblack/forgejo-thing/pulls/3"
            }
        })];

    var actions = [GH.run(ACC, {
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
            repository: {
                full_name: "muddyblack/nixos-config"
            }
        }), GH.run(ACC, {
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
            repository: {
                full_name: "muddyblack/gitpulse"
            }
        }), GH.run(ACC, {
            id: 13,
            name: "tests",
            status: "completed",
            conclusion: "success",
            head_branch: "main",
            updated_at: iso(180),
            actor: {
                login: "muddyblack"
            },
            repository: {
                full_name: "muddyblack/ai-usage-widget"
            }
        }), FJ.task(CB, {
            // A Forgejo task: one `status` string and no `conclusion`, so this
            // row is also the regression guard for reading it as GitHub's
            // shape, which rendered every failure as a grey "unknown".
            id: 91,
            name: "build",
            display_title: "drop the vendored copy",
            status: "failure",
            head_branch: "main",
            run_number: 42,
            updated_at: iso(48),
            url: "https://codeberg.org/muddyblack/forgejo-thing/actions/runs/42"
        }, "muddyblack/forgejo-thing")];

    var pulls = [GH.searchItem(ACC, {
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
            additions: 1240,
            deletions: 180,
            pull_request: {
                url: "https://api.github.com/repos/muddyblack/ai-usage-widget/pulls/58"
            }
        })];
    pulls[0].reviewRequested = true;

    var issues = [GH.searchItem(ACC, {
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
        })];

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
    var fakeProfile = GH._profileOf({
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
    // A full year of consecutive days, so the heatmap, the 30-day trend and
    // the streak figures all get something shaped like real data instead of
    // two lonely cells.
    var dayList = [];
    var seed = 7;
    var cursor = new Date(2026, 0, 4);
    for (var i = 0; i < 364; i++) {
        seed = (seed * 1103515245 + 12345) % 2147483648;
        var r = seed / 2147483648;
        var weekday = cursor.getDay();
        dayList.push({
            date: cursor.getFullYear() + "-" + ("0" + (cursor.getMonth() + 1)).slice(-2) + "-" + ("0" + cursor.getDate()).slice(-2),
            count: weekday === 0 || weekday === 6 ? Math.floor(r * 4) : Math.floor(r * r * 18)
        });
        cursor = new Date(cursor.getTime() + 86400000);
    }

    var samples = [];
    [9, 9, 10, 11, 11, 13, 14, 16, 19, 20, 20, 21, 22, 2].forEach(function (h) {
        samples.push({
            at: new Date(2026, 0, 5, h, 0, 0).toISOString(),
            count: 1 + (h % 3)
        });
    });

    var bundle = {
        profile: fakeProfile,
        calendar: Contract.calendar(dayList, 1293),
        clock: Contract.clock(samples),
        languages: [
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
        ]
    };
    core.profiles = {
        gh: bundle,
        cb: bundle
    };

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
