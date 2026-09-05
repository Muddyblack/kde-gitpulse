// Gitpulse — unit tests for the shared core.
//
//   qml -platform offscreen tests/run-tests.qml     (or: make test)
//
// Runs against the exact JS the widget ships, in the exact engine it ships on,
// which is why this is a QML file and not a node script: the code lives inside
// `.pragma library` scripts and depends on the QML engine's XMLHttpRequest.
import QtQuick
import "../package/contents/code/Format.js" as Fmt
import "../package/contents/code/Contract.js" as Contract
import "../package/contents/code/GitHub.js" as GH
import "../package/contents/code/GitLab.js" as GL
import "../package/contents/code/Forgejo.js" as FJ
import "../package/contents/code/Forge.js" as Forge
import "../package/contents/code/Http.js" as Http
import "ApiSamples.js" as Api

QtObject {
    id: suite

    property int passed: 0
    property int failed: 0
    property string group: ""

    function describe(name) {
        suite.group = name;
        console.log("\n  " + name);
    }

    function ok(label, condition, detail) {
        if (condition) {
            suite.passed++;
            console.log("    ✓ " + label);
        } else {
            suite.failed++;
            console.log("    ✗ " + label + (detail === undefined ? "" : "  — " + detail));
        }
    }

    function eq(label, actual, expected) {
        ok(label, actual === expected, "got " + JSON.stringify(actual) + ", want " + JSON.stringify(expected));
    }

    function near(label, actual, expected, tol) {
        ok(label, Math.abs(actual - expected) <= (tol === undefined ? 0.001 : tol), "got " + actual + ", want ~" + expected);
    }

    // The providers are normalisers over an account, so the suite needs one.
    readonly property var gh: Forge.normalise({
        id: "gh",
        provider: "github",
        login: "me"
    })
    readonly property var gl: Forge.normalise({
        id: "gl",
        provider: "gitlab",
        login: "me"
    })
    readonly property var cb: Forge.normalise({
        id: "cb",
        provider: "codeberg",
        login: "me"
    })

    Component.onCompleted: {
        var ACC = suite.gh;
        var GLA = suite.gl;
        var CBA = suite.cb;
        var MIN = 60000;
        var HOUR = 60 * MIN;
        var DAY = 24 * HOUR;
        var now = Date.parse("2026-08-08T12:00:00Z");

        function ago(ms) {
            return new Date(now - ms).toISOString();
        }

        // ── runtime ─────────────────────────────────────────────────────────
        describe("runtime capabilities");
        var caps = Http.capabilities();
        ok("XMLHttpRequest exists inside a pragma library", caps.xhr);
        ok("JSON exists inside a pragma library", caps.json);

        // ── Format ──────────────────────────────────────────────────────────
        describe("Format.relative");
        eq("under 45s reads as now", Fmt.relative(ago(10000), now), "now");
        eq("minutes", Fmt.relative(ago(4 * MIN), now), "4m");
        eq("hours", Fmt.relative(ago(3 * HOUR), now), "3h");
        eq("days", Fmt.relative(ago(2 * DAY), now), "2d");
        eq("weeks", Fmt.relative(ago(14 * DAY), now), "2w");
        eq("months", Fmt.relative(ago(70 * DAY), now), "2mo");
        eq("years", Fmt.relative(ago(800 * DAY), now), "2y");
        eq("empty input stays empty", Fmt.relative("", now), "");
        eq("garbage input stays empty", Fmt.relative("not-a-date", now), "");
        eq("future timestamps clamp to now", Fmt.relative(new Date(now + HOUR).toISOString(), now), "now");

        describe("Format.shortDate");
        var thisYear = new Date().getFullYear();
        eq("this year drops the year", Fmt.shortDate(thisYear + "-04-30"), "Apr 30");
        eq("another year keeps it", Fmt.shortDate("2019-01-01"), "Jan 1, 2019");
        eq("a leading zero is not a leading zero in the output", Fmt.shortDate(thisYear + "-12-05"), "Dec 5");
        eq("nonsense in, nonsense out rather than a crash", Fmt.shortDate("nope"), "nope");
        eq("empty in, empty out", Fmt.shortDate(""), "");
        eq("an impossible month is passed through", Fmt.shortDate("2026-13-01"), "2026-13-01");

        describe("Format.since");
        eq("fresh reads as just now", Fmt.since(ago(10 * 1000), now), "just now");
        eq("older gets the suffix", Fmt.since(ago(4 * MIN), now), "4m ago");
        eq("an unusable timestamp yields nothing to paste it after", Fmt.since("", now), "");

        describe("Format.compact");
        eq("small numbers pass through", Fmt.compact(420), "420");
        eq("thousands", Fmt.compact(1420), "1.4k");
        eq("round thousands drop the .0", Fmt.compact(2000), "2k");
        eq("millions", Fmt.compact(1240000), "1.2M");
        eq("undefined is an em dash", Fmt.compact(undefined), "—");

        describe("Format.diff");
        eq("additions small", Fmt.diffAdditions(12), "+12");
        eq("additions compact", Fmt.diffAdditions(1240), "+1.2k");
        eq("additions zero", Fmt.diffAdditions(0), "+0");
        eq("additions null is empty", Fmt.diffAdditions(null), "");
        eq("deletions small", Fmt.diffDeletions(8), "-8");
        eq("deletions compact", Fmt.diffDeletions(2000), "-2k");
        eq("deletions zero", Fmt.diffDeletions(0), "-0");
        eq("deletions null is empty", Fmt.diffDeletions(null), "");

        describe("Format.until");
        eq("zero is now", Fmt.until(0), "now");
        eq("seconds", Fmt.until(48), "48s");
        eq("minutes", Fmt.until(12 * 60), "12m");
        eq("hours and minutes", Fmt.until(90 * 60), "1h 30m");

        describe("Format reason + run mapping");
        eq("known reason gets a short label", Fmt.reasonLabel("review_requested"), "review");
        eq("unknown reason is humanised, not dropped", Fmt.reasonLabel("brand_new_reason"), "brand new reason");
        eq("unknown reason still gets an icon", Fmt.reasonIcon("brand_new_reason"), "mail-message");
        eq("in-progress beats conclusion", Fmt.runTone("in_progress", "failure"), "accent");
        eq("failure is negative", Fmt.runTone("completed", "failure"), "negative");
        eq("success is positive", Fmt.runTone("completed", "success"), "positive");
        eq("cancelled is muted, not a failure", Fmt.runTone("completed", "cancelled"), "muted");
        eq("queued label", Fmt.runLabel("queued", null), "queued");

        describe("Format.pull* ");
        eq("merged wins over open", Fmt.pullLabel("closed", false, true), "merged");
        eq("draft wins over open", Fmt.pullLabel("open", true, false), "draft");
        eq("closed without merge", Fmt.pullTone("closed", false, false), "negative");

        // ── GitHub URL rewriting ────────────────────────────────────────────
        describe("GitHub.webUrlFor");
        eq("pulls becomes pull", GH.webUrlFor(ACC, "https://api.github.com/repos/o/r/pulls/12"), "https://github.com/o/r/pull/12");
        eq("issues stays issues", GH.webUrlFor(ACC, "https://api.github.com/repos/o/r/issues/9"), "https://github.com/o/r/issues/9");
        eq("commits becomes commit", GH.webUrlFor(ACC, "https://api.github.com/repos/o/r/commits/abc"), "https://github.com/o/r/commit/abc");
        eq("release subjects survive", GH.webUrlFor(ACC, "https://api.github.com/repos/o/r/releases/1"), "https://github.com/o/r/releases/tag/1");
        eq("null subject falls back to the repo", GH.webUrlFor(ACC, null, "o/r"), "https://github.com/o/r");
        eq("a bare repo url degrades to the repo", GH.webUrlFor(ACC, "https://api.github.com/repos/o/r"), "https://github.com/o/r");

        // ── notifications ───────────────────────────────────────────────────
        describe("Contract.notification");
        var rawN = {
            id: "8801",
            unread: true,
            reason: "review_requested",
            updated_at: ago(4 * MIN),
            repository: {
                full_name: "muddyblack/gitpulse"
            },
            subject: {
                title: "Add the Actions tab",
                type: "PullRequest",
                url: "https://api.github.com/repos/muddyblack/gitpulse/pulls/12"
            }
        };
        var n = GH.notification(ACC, rawN);
        eq("id is namespaced by account", n.id, "gh:n:8801");
        eq("repo is carried over", n.repo, "muddyblack/gitpulse");
        eq("subject url becomes a browser url", n.url, "https://github.com/muddyblack/gitpulse/pull/12");
        eq("number is extracted", n.number, "#12");
        eq("review requests are accent-toned", n.tone, "accent");
        ok("unread survives", n.unread);

        var readN = GH.notification(ACC, {
            id: "1",
            unread: false,
            reason: "subscribed",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        });
        eq("read notifications go muted", readN.tone, "muted");
        eq("a missing title does not produce undefined", readN.title, "(no title)");

        eq("security alerts are negative", GH.notification(ACC, {
            id: "2",
            unread: true,
            reason: "security_alert",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        }).tone, "negative");

        describe("Contract.subjectKey");
        eq("pull and issue urls collapse to one key", Contract.subjectKey("gh", "https://api.github.com/repos/o/r/pulls/12"), "gh|o/r/issues/12");
        eq("issue url is already canonical", Contract.subjectKey("gh", "https://api.github.com/repos/o/r/issues/12"), "gh|o/r/issues/12");
        eq("empty in, empty out", Contract.subjectKey("gh", ""), "");
        // Two forges can both host owner/repo#1; without the account prefix
        // one of the two would be silently de-duplicated away.
        ok("the same path on two accounts is two keys", Contract.subjectKey("gh", "https://api.github.com/repos/o/r/issues/1") !== Contract.subjectKey("cb", "https://codeberg.org/api/v1/repos/o/r/issues/1"));

        // ── runs ────────────────────────────────────────────────────────────
        describe("Contract.run");
        var failedRun = GH.run(ACC, {
            id: 55,
            name: "flake-check",
            status: "completed",
            conclusion: "failure",
            head_branch: "main",
            run_number: 42,
            updated_at: ago(26 * MIN),
            html_url: "https://github.com/o/r/actions/runs/55",
            actor: {
                login: "someone-else"
            },
            _repo: "o/r"
        }, "muddyblack");
        eq("failure tone", failedRun.tone, "negative");
        eq("run number", failedRun.number, "#42");
        eq("branch lands in detail", failedRun.detail, "main");
        ok("a failure on main counts as yours even from another actor", failedRun.yours);

        var othersBranch = GH.run(ACC, {
            id: 56,
            status: "completed",
            conclusion: "failure",
            head_branch: "feature/theirs",
            actor: {
                login: "someone-else"
            },
            _repo: "o/r"
        }, "muddyblack");
        ok("a failure on someone else's branch is not yours", !othersBranch.yours);

        // ── search items ────────────────────────────────────────────────────
        describe("Contract.searchItem");
        var pr = GH.searchItem(ACC, {
            id: 900,
            number: 58,
            title: "Fix interpreter resolution",
            state: "open",
            draft: false,
            updated_at: ago(HOUR),
            html_url: "https://github.com/o/r/pull/58",
            repository_url: "https://api.github.com/repos/o/r",
            url: "https://api.github.com/repos/o/r/issues/58",
            user: {
                login: "kdeuser"
            },
            assignees: [],
            additions: 1500,
            deletions: 300,
            pull_request: {
                url: "https://api.github.com/repos/o/r/pulls/58"
            }
        }, "muddyblack");
        eq("pull requests are their own kind", pr.kind, Contract.KIND.PULL);
        eq("repo comes from repository_url", pr.repo, "o/r");
        eq("open PRs are positive", pr.tone, "positive");
        ok("authored by someone else is not yours", !pr.yours);
        eq("additions preserved", pr.additions, 1500);
        eq("deletions preserved", pr.deletions, 300);

        // The search API carries no diff sizes — every real GitHub badge comes
        // from the GraphQL follow-up, so cover the merge that lands them.
        describe("GitHub.applyDiffStats");
        var withNode = function (nodeId) {
            return GH.searchItem(ACC, {
                id: 60,
                number: 60,
                title: "Diffed",
                state: "open",
                updated_at: ago(HOUR),
                html_url: "https://github.com/o/r/pull/60",
                repository_url: "https://api.github.com/repos/o/r",
                url: "https://api.github.com/repos/o/r/issues/60",
                node_id: nodeId,
                user: {
                    login: "kdeuser"
                },
                assignees: [],
                pull_request: {
                    url: "https://api.github.com/repos/o/r/pulls/60"
                }
            }, "muddyblack");
        };

        var target = withNode("PR_abc");
        eq("a search result starts without a diff", target.additions, null);
        eq("matching nodes are folded in", GH.applyDiffStats([target], [
            {
                id: "PR_abc",
                additions: 12,
                deletions: 3
            }
        ]), 1);
        eq("additions land on the pull", target.additions, 12);
        eq("deletions land on the pull", target.deletions, 3);

        var unmatched = withNode("PR_xyz");
        eq("an id we did not ask for is ignored", GH.applyDiffStats([unmatched], [
            {
                id: "PR_other",
                additions: 5,
                deletions: 5
            }
        ]), 0);
        eq("and leaves the pull untouched", unmatched.additions, null);

        // GraphQL pads the array with nulls for ids it could not resolve.
        eq("null nodes are skipped", GH.applyDiffStats([withNode("PR_1")], [null]), 0);
        eq("a non-array payload is survivable", GH.applyDiffStats([withNode("PR_1")], undefined), 0);

        var noCounts = withNode("PR_2");
        GH.applyDiffStats([noCounts], [
            {
                id: "PR_2"
            }
        ]);
        eq("a node without counts stays null", noCounts.additions, null);

        var many = [];
        for (var d = 0; d < 130; d++)
            many.push(withNode("PR_n" + d));
        eq("the id list stays inside the GraphQL node cap", GH.pullNodeIds(many).length, 100);

        // A GraphQL body is an envelope; reading one level too high is how the
        // diff badges quietly went missing once already.
        describe("GitHub.graphqlPayload");
        var envelope = {
            ok: true,
            data: {
                data: {
                    nodes: [
                        {
                            id: "PR_abc"
                        }
                    ]
                }
            }
        };
        eq("unwraps the envelope, not the response", GH.graphqlPayload(envelope).nodes.length, 1);
        ok("a failed call has no payload", GH.graphqlPayload({
            ok: false,
            data: envelope.data
        }) === null);
        ok("an errors-only body has no payload", GH.graphqlPayload({
            ok: true,
            data: {
                errors: [
                    {
                        message: "nope"
                    }
                ]
            }
        }) === null);
        ok("a bodyless response has no payload", GH.graphqlPayload({
            ok: true
        }) === null);

        var issue = GH.searchItem(ACC, {
            id: 901,
            number: 9,
            title: "Badge count wrong",
            state: "open",
            updated_at: ago(3 * HOUR),
            html_url: "https://github.com/o/r/issues/9",
            repository_url: "https://api.github.com/repos/o/r",
            url: "https://api.github.com/repos/o/r/issues/9",
            user: {
                login: "me"
            },
            assignees: [
                {
                    login: "me"
                }
            ],
            labels: [
                {
                    name: "bug"
                },
                {
                    name: "ui"
                }
            ]
        });
        eq("issues are their own kind", issue.kind, Contract.KIND.ISSUE);
        ok("assignment is detected", issue.assigned);
        eq("labels become the detail line", issue.detail, "bug, ui");

        // ── badge arithmetic ────────────────────────────────────────────────
        describe("Contract.needsYou");
        ok("unread review request needs you", Contract.needsYou(n));
        ok("read review request does not", !Contract.needsYou(GH.notification(ACC, {
            id: "3",
            unread: false,
            reason: "review_requested",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        })));
        ok("ci_activity never needs you on its own", !Contract.needsYou(GH.notification(ACC, {
            id: "4",
            unread: true,
            reason: "ci_activity",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        })));
        ok("your failed run needs you", Contract.needsYou(failedRun));
        ok("someone else's failed run does not", !Contract.needsYou(othersBranch));
        ok("an assigned issue never needs you", !Contract.needsYou(issue));
        pr.reviewRequested = true;
        ok("a review-requested PR needs you", Contract.needsYou(pr));

        describe("Contract.dedupe + badge");
        // The same pull request arrives twice: once as an inbox notification,
        // once as a review-requested PR. It must count once.
        var dupNotification = GH.notification(ACC, {
            id: "9001",
            unread: true,
            reason: "review_requested",
            updated_at: ago(5 * MIN),
            repository: {
                full_name: "o/r"
            },
            subject: {
                title: "Fix interpreter resolution",
                type: "PullRequest",
                url: "https://api.github.com/repos/o/r/pulls/58"
            }
        });
        var sections = {
            inbox: [dupNotification],
            actions: [failedRun, othersBranch],
            pulls: [pr],
            issues: [issue]
        };
        var b = Contract.badge(sections);
        eq("the duplicated PR is counted once", b.needsYou, 2);
        eq("the inbox keeps the count", b.perTab.inbox, 1);
        eq("the pulls tab yields it", b.perTab.pulls, 0);
        ok("the PR is flagged as a duplicate", pr.duplicate);
        eq("failing runs are still reported for the tooltip", b.failing, 2);
        eq("review count is independent of the badge", b.toReview, 1);
        eq("tracked counts everything on screen", b.tracked, 5);

        // ── sorting ─────────────────────────────────────────────────────────
        describe("Contract.sortItems");
        var mixed = [GH.notification(ACC, {
                id: "s1",
                unread: true,
                reason: "subscribed",
                updated_at: ago(MIN),
                repository: {
                    full_name: "a/b"
                },
                subject: {}
            }), GH.notification(ACC, {
                id: "s2",
                unread: true,
                reason: "mention",
                updated_at: ago(10 * HOUR),
                repository: {
                    full_name: "a/b"
                },
                subject: {}
            })];
        var sorted = Contract.sortItems(mixed, "inbox");
        eq("needs-you outranks recency", sorted[0].id, "gh:n:s2");

        var runs = Contract.sortItems([GH.run(ACC, {
                id: 1,
                status: "completed",
                conclusion: "success",
                updated_at: ago(MIN),
                _repo: "a/b"
            }), GH.run(ACC, {
                id: 2,
                status: "completed",
                conclusion: "failure",
                updated_at: ago(DAY),
                _repo: "a/b"
            }), GH.run(ACC, {
                id: 3,
                status: "in_progress",
                updated_at: ago(2 * MIN),
                _repo: "a/b"
            })], "actions");
        eq("failures sort first", runs[0].runId, 2);
        eq("running sorts above passing", runs[1].runId, 3);

        describe("Contract.search + groupByRepo");
        var pool = [GH.notification(ACC, {
                id: "f1",
                unread: true,
                reason: "mention",
                repository: {
                    full_name: "muddyblack/gitpulse"
                },
                subject: {
                    title: "Panel margin regression"
                }
            }), GH.notification(ACC, {
                id: "f2",
                unread: true,
                reason: "mention",
                repository: {
                    full_name: "muddyblack/dotfiles"
                },
                subject: {
                    title: "Waybar cleanup"
                }
            })];
        eq("search matches titles", Contract.search(pool, "margin").length, 1);
        eq("search matches repositories", Contract.search(pool, "dotfiles").length, 1);
        eq("search is case-insensitive", Contract.search(pool, "WAYBAR").length, 1);
        eq("empty query returns everything", Contract.search(pool, "").length, 2);
        eq("grouping yields one bucket per repo", Contract.groupByRepo(pool).length, 2);

        // ── profile ─────────────────────────────────────────────────────────
        describe("Contract.profile");
        var userNode = {
            login: "muddyblack",
            name: "Muddyblack",
            bio: "information should be free",
            avatarUrl: "https://example.invalid/a.png",
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
                        stargazerCount: 100,
                        languages: {
                            edges: [
                                {
                                    size: 800,
                                    node: {
                                        name: "Python",
                                        color: "#3572A5"
                                    }
                                },
                                {
                                    size: 100,
                                    node: {
                                        name: "QML",
                                        color: "#44a51c"
                                    }
                                }
                            ]
                        }
                    },
                    {
                        nameWithOwner: "muddyblack/b",
                        stargazerCount: 39,
                        languages: {
                            edges: [
                                {
                                    size: 100,
                                    node: {
                                        name: "Python",
                                        color: "#3572A5"
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
                    weeks: []
                }
            }
        };
        var p = GH._profileOf(userNode);
        eq("stars are summed across repos", p.starsEarned, 139);
        eq("follower count", p.followers, 76);
        eq("commit contributions", p.commits, 22);
        eq("private contributions are surfaced separately", p.privateContributions, 4);
        ok("an empty spec still yields a profile shape", Contract.profile(null).login === "");

        describe("Contract.languages");
        var langs = GH._languagesOf(userNode);
        eq("most-used language leads", langs[0].name, "Python");
        near("shares are percentages that sum to 100", langs.reduce(function (s, l) {
            return s + l.share;
        }, 0), 100, 0.01);
        eq("colours come from the API", langs[0].color, "#3572A5");
        eq("no repos means no bar rather than a crash", GH._languagesOf({}).length, 0);

        describe("Contract.calendar");
        // The calendar is now provider-neutral: a flat [{date, count}] list,
        // which GitHub's GraphQL weeks, Forgejo's heatmap and GitLab's
        // calendar.json all reduce to.
        function days(counts, startIso) {
            var day = new Date((startIso || "2026-01-04") + "T12:00:00Z");
            return counts.map(function (c, i) {
                var d = new Date(day.getTime() + i * 86400000);
                return {
                    date: Fmt.isoDate(d),
                    count: c
                };
            });
        }
        // 2026-01-04 is a Sunday, so fourteen days is exactly two grid columns.
        var cal = Contract.calendar(days([0, 1, 2, 3, 4, 5, 15, 0, 0, 0, 0, 0, 0, 0]), 30);
        eq("total is carried through", cal.total, 30);
        eq("two weeks in, two weeks out", cal.weeks.length, 2);
        eq("a quiet day is level 0", cal.weeks[0][0].level, 0);
        eq("the busiest day saturates at level 4", cal.weeks[0][6].level, 4);
        ok("a light day is not level 0", cal.weeks[0][1].level >= 1);
        eq("longest streak counts consecutive active days", cal.streak, 6);
        eq("the record streak reports its span", cal.streakSpan[1], "2026-01-10");
        eq("busiest day is reported", cal.busiest, 15);
        ok("an empty day list returns null", Contract.calendar([]) === null);
        eq("a flat chronological day list is exposed", cal.days.length, 14);
        eq("the last 30 days are sliced out for the trend chart", cal.recent.length, 14);
        eq("the busiest date is reported", cal.busiestDate, "2026-01-10");
        near("the daily average is total over days", cal.average, 30 / 14, 0.01);
        eq("without an explicit total the counts are summed", Contract.calendar(days([1, 2, 3])).total, 6);

        // A week that starts mid-week must still align to the right column,
        // or the whole grid shears by a day.
        var midWeek = Contract.calendar(days([1, 1, 1], "2026-01-01"));
        ok("a range starting on a Thursday pads the leading days", midWeek.weeks[0][0] === null);
        ok("the first real cell lands on Thursday", midWeek.weeks[0][4] !== null);

        describe("GitHub calendar payload");
        var ghCal = GH._calendarOf({
            contributionCalendar: {
                totalContributions: 6,
                weeks: [
                    {
                        contributionDays: [
                            {
                                date: "2026-01-04",
                                contributionCount: 1
                            },
                            {
                                date: "2026-01-05",
                                contributionCount: 5
                            }
                        ]
                    }
                ]
            }
        });
        eq("GraphQL weeks flatten into the shared calendar", ghCal.total, 6);
        eq("and keep their days", ghCal.days.length, 2);
        ok("a collection with no calendar is null, not a crash", GH._calendarOf({}) === null);

        describe("Contract.calendar current streak");
        function calFrom(rows) {
            return Contract.calendar(days(rows));
        }
        eq("counts back from the most recent day", calFrom([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5]).current, 5);
        // Today being quiet must not reset the streak: the day is not over, and
        // a number that flips at midnight is a number nobody trusts.
        eq("a quiet today does not break the streak", calFrom([0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 0]).current, 5);
        eq("two quiet days do break it", calFrom([0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 0, 0, 0, 0]).current, 0);
        eq("an all-quiet year is zero, not NaN", calFrom([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]).current, 0);
        eq("an unbroken run counts every day", calFrom([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]).current, 14);

        // ── the hour dial ───────────────────────────────────────────────────
        describe("Contract.clock");
        function at(hour, count) {
            return {
                at: new Date(2026, 0, 5, hour, 30, 0).toISOString(),
                count: count
            };
        }
        var dial = Contract.clock([at(9), at(10), at(11), at(20), at(21), at(2)]);
        eq("there is one bucket per hour of the day", dial.hours.length, 24);
        eq("an hour with one commit has one", dial.hours[9], 1);
        eq("an empty hour is zero, not undefined", dial.hours[4], 0);
        eq("the total is the number of commits", dial.total, 6);
        eq("the peak hour is found", dial.peak, 1);
        eq("no samples means no dial rather than a divide by zero", Contract.clock([]), null);
        eq("unparseable timestamps are skipped", Contract.clock([
            {
                at: "nonsense"
            }
        ]), null);
        // A nine-commit push is nine commits at that hour, not one event.
        eq("counts are weights, not tallies", Contract.clock([at(14, 9)]).hours[14], 9);
        eq("and they reach the total", Contract.clock([at(14, 9)]).total, 9);
        ok("the dial names the timezone it is drawn in", dial.tz.indexOf("utc") === 0);

        describe("Contract.rhythm");
        var beat = Contract.rhythm(dial);
        eq("buckets are ranked busiest first", beat[0].name, "morning");
        eq("the busiest bucket has its count", beat[0].count, 3);
        near("shares are percentages", beat[0].share, 50, 0.01);
        near("every bucket sums to 100", beat.reduce(function (s, b) {
            return s + b.share;
        }, 0), 100, 0.01);
        eq("late night lands in night, not evening", Contract.rhythm(Contract.clock([at(2)]))[0].name, "night");
        eq("midday lands in day", Contract.rhythm(Contract.clock([at(13)]))[0].name, "day");
        eq("no dial means no chart", Contract.rhythm(null).length, 0);

        describe("Contract avatars");
        eq("notifications carry the owner picture", GH.notification(ACC, {
            id: "av",
            unread: true,
            reason: "mention",
            repository: {
                full_name: "a/b",
                owner: {
                    avatar_url: "https://example.invalid/o.png"
                }
            },
            subject: {}
        }).avatarUrl, "https://example.invalid/o.png");
        eq("a payload without an owner yields an empty string, not undefined", GH.notification(ACC, {
            id: "av2",
            unread: true,
            reason: "mention",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        }).avatarUrl, "");

        // ── the other two forges ────────────────────────────────────────────
        //
        // The point of these is not that GitLab's JSON parses — it is that a
        // GitLab todo and a GitHub notification come out of their providers
        // indistinguishable to the badge, the chips and the rows.
        describe("GitLab.todo");
        var todo = GL.todo(GLA, {
            id: 77,
            action_name: "review_requested",
            state: "pending",
            target_type: "MergeRequest",
            created_at: ago(9 * MIN),
            target_url: "https://gitlab.com/g/p/-/merge_requests/4",
            target: {
                title: "Bump the runner image",
                iid: 4,
                web_url: "https://gitlab.com/g/p/-/merge_requests/4"
            },
            project: {
                path_with_namespace: "g/p"
            },
            author: {
                username: "someone"
            }
        });
        eq("a review request keeps its meaning across forges", todo.reason, "review_requested");
        eq("and therefore its tone", todo.tone, "accent");
        ok("and reaches the badge", Contract.needsYou(todo));
        eq("nested group paths survive", todo.repo, "g/p");
        eq("merge requests are numbered the GitLab way", todo.number, "!4");
        eq("the item knows which forge it came from", todo.provider, "gitlab");
        eq("a build failure is not somebody waiting on you", GL.todo(GLA, {
            id: 78,
            action_name: "build_failed",
            state: "pending",
            target: {},
            project: {}
        }).reason, "ci_activity");

        describe("GitLab pipelines");
        eq("success maps to a completed success", GL.runState("success").join("/"), "completed/success");
        eq("failed maps to a completed failure", GL.runState("failed").join("/"), "completed/failure");
        eq("running maps to in_progress", GL.runState("running")[0], "in_progress");
        eq("an unknown status queues rather than throwing", GL.runState("waiting_for_resource")[0], "queued");
        var pipe = GL.pipeline(GLA, {
            id: 5,
            iid: 12,
            status: "failed",
            ref: "main",
            web_url: "https://gitlab.com/g/p/-/pipelines/5",
            updated_at: ago(2 * MIN),
            source: "merge_request_event"
        }, {
            name: "g/p",
            branch: "main",
            avatar: ""
        });
        eq("a failed pipeline is negative, same as a failed run", pipe.tone, "negative");
        ok("a failure on the default branch is yours", pipe.yours);
        ok("and therefore reaches the badge", Contract.needsYou(pipe));

        describe("GitLab merge requests");
        var mr = GL.mergeRequest(GLA, {
            id: 31,
            iid: 8,
            title: "Drop the vendored copy",
            state: "opened",
            draft: false,
            updated_at: ago(HOUR),
            web_url: "https://gitlab.com/g/sub/p/-/merge_requests/8",
            author: {
                username: "me"
            },
            user_notes_count: 3
        });
        eq("deeply nested projects keep their whole path", mr.repo, "g/sub/p");
        eq("an open merge request is positive", mr.tone, "positive");
        ok("authorship is detected", mr.yours);
        eq("and it is a pull request as far as the UI is concerned", mr.kind, Contract.KIND.PULL);

        describe("Forgejo.notification");
        var fn = FJ.notification(CBA, {
            id: 12,
            unread: true,
            updated_at: ago(20 * MIN),
            repository: {
                full_name: "o/r",
                owner: {
                    avatar_url: "https://codeberg.org/a.png"
                }
            },
            subject: {
                title: "Fix the build",
                type: "Pull",
                html_url: "https://codeberg.org/o/r/pulls/3"
            }
        });
        eq("a pull subject means a review is wanted", fn.reason, "review_requested");
        eq("the repository picture is used", fn.avatarUrl, "https://codeberg.org/a.png");
        eq("the number is read off the url", fn.number, "#3");
        eq("the item knows its host", fn.host, "https://codeberg.org");
        eq("an issue subject is only a subscription", FJ.notification(CBA, {
            id: 13,
            unread: true,
            repository: {},
            subject: {
                type: "Issue"
            }
        }).reason, "subscribed");

        describe("Forgejo activity");
        // The heatmap endpoint is second-resolution, so one call fills both
        // the calendar and the hour dial.
        var noonUtc = Math.floor(Date.UTC(2026, 0, 5, 12, 0, 0) / 1000);
        var heat = [
            {
                timestamp: noonUtc,
                contributions: 3
            },
            {
                timestamp: noonUtc + 86400,
                contributions: 1
            }
        ];
        var byDay = {};
        heat.forEach(function (h) {
            var k = Fmt.localDate(new Date(h.timestamp * 1000));
            byDay[k] = (byDay[k] || 0) + h.contributions;
        });
        eq("two timestamps become two days", Object.keys(byDay).length, 2);

        // ── against real payloads ───────────────────────────────────────────
        //
        // Everything above proves the normalisers are self-consistent. These
        // prove they match the forge: the GitLab samples were captured live
        // from gitlab.com, the Forgejo ones built field-for-field from the
        // published API spec. See tests/ApiSamples.js.
        describe("GitLab — recorded payloads");
        var livePipe = GL.pipeline(GLA, Api.GITLAB_PIPELINE, {
            name: "gitlab-org/gitlab",
            branch: "master",
            avatar: ""
        });
        eq("a live pipeline keeps its number", livePipe.number, "#" + Api.GITLAB_PIPELINE.iid);
        eq("and its branch", livePipe.detail, Api.GITLAB_PIPELINE.ref);
        eq("and its web link", livePipe.url, Api.GITLAB_PIPELINE.web_url);
        ok("a live status maps to a tone the UI knows", ["positive", "negative", "neutral", "accent", "muted"].indexOf(livePipe.tone) >= 0, livePipe.tone);
        ok("and never to the empty label", livePipe.label !== "" && livePipe.label !== "unknown", livePipe.label);

        // Every status GitLab documents has to land somewhere real; a status
        // that falls through to "unknown" is a grey row nobody can act on.
        ["created", "waiting_for_resource", "preparing", "pending", "running", "success", "failed", "canceled", "canceling", "skipped", "manual", "scheduled"].forEach(function (st) {
            var pair = GL.runState(st);
            ok("gitlab status " + st + " maps to a known pair", pair.length === 2 && Fmt.runLabel(pair[0], pair[1]) !== "unknown", JSON.stringify(pair));
        });

        var liveProject = Api.GITLAB_PROJECT;
        ok("the project payload still has path_with_namespace", typeof liveProject.path_with_namespace === "string" && liveProject.path_with_namespace.indexOf("/") > 0);
        ok("and default_branch, which decides whether a pipeline is yours", "default_branch" in liveProject);
        ok("and star_count, which the profile totals", "star_count" in liveProject);

        var liveLangs = [];
        for (var lname in Api.GITLAB_LANGUAGES)
            liveLangs.push({
                name: lname,
                bytes: Api.GITLAB_LANGUAGES[lname],
                color: Fmt.languageColor(lname)
            });
        var liveMix = Contract.languages(liveLangs, 6);
        ok("a live language map yields a bar", liveMix.length > 0);
        near("whose shares sum to 100", liveMix.reduce(function (acc, l) {
            return acc + l.share;
        }, 0), 100, 0.01);
        ok("and every stripe has a colour, even though GitLab sends none", liveMix.every(function (l) {
            return l.name === "Other" || l.color !== "";
        }));

        var pushEvent = Api.GITLAB_PUSH_EVENT;
        eq("the push action is still spelled this way", pushEvent.action_name, "pushed to");
        ok("and still carries a commit count", pushEvent.push_data && typeof pushEvent.push_data.commit_count === "number");
        // A nine-commit push has to weigh nine on the dial, not one.
        var pushDial = Contract.clock([
            {
                at: pushEvent.created_at,
                count: pushEvent.push_data.commit_count
            }
        ]);
        eq("a push weighs its commits on the dial", pushDial.total, pushEvent.push_data.commit_count);

        var liveCal = [];
        for (var d in Api.GITLAB_CALENDAR)
            liveCal.push({
                date: d,
                count: Api.GITLAB_CALENDAR[d]
            });
        var calFromGitlab = Contract.calendar(liveCal);
        ok("calendar.json feeds the heatmap directly", calFromGitlab !== null && calFromGitlab.days.length === liveCal.length);

        var liveTodo = GL.todo(GLA, Api.GITLAB_TODO);
        eq("a todo becomes a notification", liveTodo.kind, Contract.KIND.NOTIFICATION);
        eq("with the project path as its repo", liveTodo.repo, "group/project");
        ok("and reaches the badge", Contract.needsYou(liveTodo));

        describe("Forgejo — spec-shaped payloads");
        var fjNote = FJ.notification(CBA, Api.FORGEJO_NOTIFICATION);
        eq("the subject title survives", fjNote.title, "Drop the vendored copy");
        eq("the browser link is used, not the API one", fjNote.url, Api.FORGEJO_NOTIFICATION.subject.html_url);
        ok("and it reaches the badge", Contract.needsYou(fjNote));

        // The bug this file exists for: ActionTask has no `conclusion`, so
        // reading it as GitHub's shape rendered every finished run — failures
        // included — as a muted "unknown" that never reached the badge.
        var fjRuns = Api.FORGEJO_TASKS.workflow_runs.map(function (t) {
            return FJ.task(CBA, t, "muddyblack/forgejo-thing");
        });
        eq("a failed task is negative", fjRuns[0].tone, "negative");
        eq("and says so", fjRuns[0].label, "failure");
        ok("and, on the default branch, is yours", fjRuns[0].yours);
        ok("so it reaches the badge", Contract.needsYou(fjRuns[0]));
        eq("a running task is accent-toned", fjRuns[1].tone, "accent");
        ok("and is marked running", fjRuns[1].running);
        eq("the task's own url is the link", fjRuns[0].url, Api.FORGEJO_TASKS.workflow_runs[0].url);
        eq("the run number survives", fjRuns[0].number, "#42");

        Api.FORGEJO_STATUSES.forEach(function (st) {
            var pair = FJ.runState(st);
            ok("forgejo status " + st + " maps to a known pair", pair.length === 2, JSON.stringify(pair));
            var tone = Fmt.runTone(pair[0], pair[1]);
            ok("  and to a tone the UI knows: " + st, ["positive", "negative", "neutral", "accent", "muted"].indexOf(tone) >= 0, tone);
        });
        eq("success is positive", Fmt.runTone.apply(null, FJ.runState("success")), "positive");
        eq("failure is negative", Fmt.runTone.apply(null, FJ.runState("failure")), "negative");
        eq("cancelled is muted, not a failure", Fmt.runTone.apply(null, FJ.runState("cancelled")), "muted");

        var heat = Api.FORGEJO_HEATMAP;
        ok("the heatmap is timestamp plus contributions", "timestamp" in heat[0] && "contributions" in heat[0]);
        var heatDial = Contract.clock(heat.map(function (h) {
            return {
                at: h.timestamp * 1000,
                count: h.contributions
            };
        }));
        eq("one heatmap call fills the dial too", heatDial.total, 4);

        var fjUser = Api.FORGEJO_USER;
        var fjProfile = Contract.profile({
            login: fjUser.login,
            name: fjUser.full_name,
            bio: fjUser.description,
            followers: fjUser.followers_count,
            starred: fjUser.starred_repos_count,
            provider: "codeberg"
        });
        eq("full_name is the display name", fjProfile.name, "Muddyblack");
        eq("followers_count is the follower count", fjProfile.followers, 12);
        // Forgejo publishes no review count; a missing figure must stay null so
        // the tile is dropped rather than showing a confident zero.
        ok("a figure Forgejo does not publish stays null", fjProfile.reviews === null);
        eq("and renders as an em dash", Fmt.compact(fjProfile.reviews), "—");

        // The recorded payload assigns muddyblack, so the account reading it
        // has to be muddyblack — "assigned to me" is only meaningful relative
        // to a login.
        var mine = Forge.normalise({
            id: "cb",
            provider: "codeberg",
            login: "muddyblack"
        });
        var fjPull = FJ.pull(mine, Api.FORGEJO_PULL);
        eq("a pull request keeps its repository", fjPull.repo, "muddyblack/forgejo-thing");
        eq("and its number", fjPull.number, "#3");
        eq("an open pull request is positive", fjPull.tone, "positive");
        ok("assignment is detected through assignees", fjPull.assigned);
        ok("someone else's pull request is not yours", !fjPull.yours);
        // A pull request's detail line is its comment count; labels are what
        // an issue puts there instead.
        eq("the comment count is the detail line", fjPull.detail, "2 comments");
        eq("an issue puts its labels there instead", FJ.issue(mine, Api.FORGEJO_PULL).detail, "cleanup");

        var fjRepo = Api.FORGEJO_REPO;
        ok("the repo payload still spells it stars_count", "stars_count" in fjRepo);
        ok("and fork, which excludes it from the profile total", "fork" in fjRepo);

        // ── accounts ────────────────────────────────────────────────────────
        describe("Forge accounts");
        eq("an unknown provider falls back to GitHub", Forge.descriptor("nope").id, "github");
        eq("a blank host takes the forge default", Forge.normalise({
            provider: "codeberg"
        }).host, "https://codeberg.org");
        eq("a trailing slash is trimmed", Forge.normalise({
            provider: "gitlab",
            host: "https://git.example.com/"
        }).host, "https://git.example.com");
        eq("round-tripping the list preserves it", Forge.parse(Forge.stringify([Forge.normalise({
                id: "x",
                provider: "gitlab",
                token: "t"
            })]))[0].provider, "gitlab");
        eq("a corrupt account string yields no accounts, not a crash", Forge.parse("{{{").length, 0);
        eq("an empty string yields no accounts", Forge.parse("").length, 0);
        eq("accounts without a credential are never polled", Forge.active([Forge.normalise({
                id: "a",
                provider: "github"
            })], "").length, 0);
        eq("a disabled account is not polled either", Forge.active([Forge.normalise({
                id: "a",
                provider: "github",
                token: "t",
                enabled: false
            })], "").length, 0);
        eq("an account borrowing the CLI token gets it", Forge.active([Forge.normalise({
                id: "a",
                provider: "github",
                useCli: true
            })], "borrowed")[0].token, "borrowed");
        eq("a 1.x token becomes the first account", Forge.migrate("ghp_x", "", false)[0].token, "ghp_x");
        eq("and keeps a stable id so its rows survive the upgrade", Forge.migrate("ghp_x", "", false)[0].id, "github");
        eq("nothing to migrate yields nothing", Forge.migrate("", "", false).length, 0);
        eq("the public instance is named plainly", Forge.displayName(Forge.normalise({
            provider: "gitlab"
        })), "GitLab");
        eq("a self-hosted one names its host", Forge.displayName(Forge.normalise({
            provider: "gitlab",
            host: "https://git.example.com"
        })), "GitLab (git.example.com)");
        eq("a label wins over both", Forge.displayName(Forge.normalise({
            provider: "gitlab",
            label: "Work"
        })), "Work");

        describe("Forge capabilities");
        ok("Copilot is a GitHub concept", Forge.capabilities(suite.gh).copilot);
        ok("and GitLab does not pretend to have it", !Forge.capabilities(suite.gl).copilot);
        ok("Forgejo cannot re-run a workflow over the API", !Forge.capabilities(suite.cb).rerun);
        ok("but it can mark a notification read", Forge.capabilities(suite.cb).markRead);

        describe("Forge item URLs");
        eq("GitHub spells it /pull/", Forge.itemPullUrl({
            provider: "github",
            host: "https://github.com",
            repo: "o/r",
            pullNumber: 3
        }), "https://github.com/o/r/pull/3");
        eq("GitLab spells it /-/merge_requests/", Forge.itemPullUrl({
            provider: "gitlab",
            host: "https://gitlab.com",
            repo: "g/p",
            pullNumber: 3
        }), "https://gitlab.com/g/p/-/merge_requests/3");
        eq("Forgejo spells it /pulls/", Forge.itemPullUrl({
            provider: "codeberg",
            host: "https://codeberg.org",
            repo: "o/r",
            pullNumber: 3
        }), "https://codeberg.org/o/r/pulls/3");
        eq("an item with no pull number has no pull url", Forge.itemPullUrl({
            provider: "github",
            repo: "o/r"
        }), "");

        describe("GitHub Enterprise");
        var ghes = Forge.normalise({
            id: "e",
            provider: "github",
            host: "https://github.example.com",
            token: "t"
        });
        eq("the REST base moves to /api/v3", GH.apiBase(ghes), "https://github.example.com/api/v3");
        eq("and GraphQL to /api/graphql", GH.graphqlUrl(ghes), "https://github.example.com/api/graphql");
        eq("github.com keeps its own API domain", GH.apiBase(suite.gh), "https://api.github.com");

        // ── mixed-forge badge ───────────────────────────────────────────────
        describe("badge across forges");
        var twoForges = {
            inbox: [GH.notification(ACC, {
                    id: "m1",
                    unread: true,
                    reason: "mention",
                    repository: {
                        full_name: "o/r"
                    },
                    subject: {
                        url: "https://api.github.com/repos/o/r/issues/1"
                    }
                }), GL.todo(GLA, {
                    id: 90,
                    action_name: "mentioned",
                    state: "pending",
                    target: {
                        title: "t",
                        iid: 1,
                        web_url: "https://gitlab.com/o/r/-/issues/1"
                    },
                    project: {
                        path_with_namespace: "o/r"
                    }
                })],
            actions: [],
            pulls: [],
            issues: []
        };
        var mixedBadge = Contract.badge(twoForges);
        eq("both forges count towards one number", mixedBadge.needsYou, 2);
        eq("and both are unread", mixedBadge.unread, 2);

        // ── service status ──────────────────────────────────────────────────
        describe("Contract.incidentStrip");
        var strip = Contract.incidentStrip([
            {
                impact: "major",
                created_at: new Date(now - 3 * DAY).toISOString(),
                resolved_at: new Date(now - 3 * DAY + 2 * HOUR).toISOString(),
                components: [
                    {
                        id: "actions"
                    }
                ]
            },
            {
                impact: "minor",
                created_at: new Date(now - 40 * DAY).toISOString(),
                resolved_at: new Date(now - 40 * DAY + HOUR).toISOString(),
                components: [
                    {
                        id: "webhooks"
                    }
                ]
            }
        ], "actions", 90, now);
        eq("the strip is the requested length", strip.length, 90);
        eq("the incident day is marked negative", strip[86].tone, "negative");
        eq("an untouched day stays positive", strip[80].tone, "positive");
        eq("another component's incident is ignored", strip[49].tone, "positive");
        var sum = Contract.stripSummary(strip);
        eq("one incident day is counted", sum.incidentDays, 1);
        eq("the rest are clean", sum.cleanDays, 89);

        describe("Contract.components");
        var summary = {
            components: [
                {
                    id: "1",
                    name: "Git Operations",
                    status: "operational",
                    showcase: true
                },
                {
                    id: "2",
                    name: "Actions",
                    status: "major_outage",
                    showcase: true
                },
                {
                    id: "3",
                    name: "Copilot",
                    status: "degraded_performance",
                    showcase: true
                },
                {
                    id: "g",
                    name: "A group",
                    status: "operational",
                    showcase: true,
                    group: true
                }
            ]
        };
        eq("groups are dropped", Contract.components(summary, true).length, 3);
        eq("outages map to negative", Contract.components(summary, true)[1].tone, "negative");
        eq("degraded maps to neutral", Contract.components(summary, true)[2].tone, "neutral");
        eq("copilot components are found by name", Contract.copilotComponents(summary).length, 1);
        eq("active incidents exclude resolved ones", Contract.activeIncidents([
            {
                status: "resolved"
            },
            {
                status: "investigating"
            }
        ]).length, 1);

        // ── done ────────────────────────────────────────────────────────────
        console.log("\n  " + suite.passed + " passed, " + suite.failed + " failed\n");
        Qt.exit(suite.failed > 0 ? 1 : 0);
    }
}
