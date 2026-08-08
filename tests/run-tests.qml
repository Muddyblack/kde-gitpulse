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

    Component.onCompleted: {
        var MIN = 60000;
        var HOUR = 60 * MIN;
        var DAY = 24 * HOUR;
        var now = Date.parse("2026-08-08T12:00:00Z");

        function ago(ms) {
            return new Date(now - ms).toISOString();
        }

        // ── runtime ─────────────────────────────────────────────────────────
        describe("runtime capabilities");
        var caps = GH.capabilities();
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

        describe("Format.compact");
        eq("small numbers pass through", Fmt.compact(420), "420");
        eq("thousands", Fmt.compact(1420), "1.4k");
        eq("round thousands drop the .0", Fmt.compact(2000), "2k");
        eq("millions", Fmt.compact(1240000), "1.2M");
        eq("undefined is an em dash", Fmt.compact(undefined), "—");

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
        eq("pulls becomes pull", GH.webUrlFor("https://api.github.com/repos/o/r/pulls/12"), "https://github.com/o/r/pull/12");
        eq("issues stays issues", GH.webUrlFor("https://api.github.com/repos/o/r/issues/9"), "https://github.com/o/r/issues/9");
        eq("commits becomes commit", GH.webUrlFor("https://api.github.com/repos/o/r/commits/abc"), "https://github.com/o/r/commit/abc");
        eq("release subjects survive", GH.webUrlFor("https://api.github.com/repos/o/r/releases/1"), "https://github.com/o/r/releases/tag/1");
        eq("null subject falls back to the repo", GH.webUrlFor(null, "o/r"), "https://github.com/o/r");
        eq("a bare repo url degrades to the repo", GH.webUrlFor("https://api.github.com/repos/o/r"), "https://github.com/o/r");

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
        var n = Contract.notification(rawN);
        eq("id is namespaced", n.id, "n:8801");
        eq("repo is carried over", n.repo, "muddyblack/gitpulse");
        eq("subject url becomes a browser url", n.url, "https://github.com/muddyblack/gitpulse/pull/12");
        eq("number is extracted", n.number, "#12");
        eq("review requests are accent-toned", n.tone, "accent");
        ok("unread survives", n.unread);

        var readN = Contract.notification({
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

        eq("security alerts are negative", Contract.notification({
            id: "2",
            unread: true,
            reason: "security_alert",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        }).tone, "negative");

        describe("Contract.subjectKey");
        eq("pull and issue urls collapse to one key", Contract.subjectKey("https://api.github.com/repos/o/r/pulls/12"), "o/r/issues/12");
        eq("issue url is already canonical", Contract.subjectKey("https://api.github.com/repos/o/r/issues/12"), "o/r/issues/12");
        eq("empty in, empty out", Contract.subjectKey(""), "");

        // ── runs ────────────────────────────────────────────────────────────
        describe("Contract.run");
        var failedRun = Contract.run({
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

        var othersBranch = Contract.run({
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
        var pr = Contract.searchItem({
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
            pull_request: {
                url: "https://api.github.com/repos/o/r/pulls/58"
            }
        }, "muddyblack");
        eq("pull requests are their own kind", pr.kind, Contract.KIND.PULL);
        eq("repo comes from repository_url", pr.repo, "o/r");
        eq("open PRs are positive", pr.tone, "positive");
        ok("authored by someone else is not yours", !pr.yours);

        var issue = Contract.searchItem({
            id: 901,
            number: 9,
            title: "Badge count wrong",
            state: "open",
            updated_at: ago(3 * HOUR),
            html_url: "https://github.com/o/r/issues/9",
            repository_url: "https://api.github.com/repos/o/r",
            url: "https://api.github.com/repos/o/r/issues/9",
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
                },
                {
                    name: "ui"
                }
            ]
        }, "muddyblack");
        eq("issues are their own kind", issue.kind, Contract.KIND.ISSUE);
        ok("assignment is detected", issue.assigned);
        eq("labels become the detail line", issue.detail, "bug, ui");

        // ── badge arithmetic ────────────────────────────────────────────────
        describe("Contract.needsYou");
        ok("unread review request needs you", Contract.needsYou(n));
        ok("read review request does not", !Contract.needsYou(Contract.notification({
            id: "3",
            unread: false,
            reason: "review_requested",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        })));
        ok("ci_activity never needs you on its own", !Contract.needsYou(Contract.notification({
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
        var dupNotification = Contract.notification({
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
        var mixed = [Contract.notification({
                id: "s1",
                unread: true,
                reason: "subscribed",
                updated_at: ago(MIN),
                repository: {
                    full_name: "a/b"
                },
                subject: {}
            }), Contract.notification({
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
        eq("needs-you outranks recency", sorted[0].id, "n:s2");

        var runs = Contract.sortItems([Contract.run({
                id: 1,
                status: "completed",
                conclusion: "success",
                updated_at: ago(MIN),
                _repo: "a/b"
            }, "me"), Contract.run({
                id: 2,
                status: "completed",
                conclusion: "failure",
                updated_at: ago(DAY),
                _repo: "a/b"
            }, "me"), Contract.run({
                id: 3,
                status: "in_progress",
                updated_at: ago(2 * MIN),
                _repo: "a/b"
            }, "me")], "actions");
        eq("failures sort first", runs[0].runId, 2);
        eq("running sorts above passing", runs[1].runId, 3);

        describe("Contract.search + groupByRepo");
        var pool = [Contract.notification({
                id: "f1",
                unread: true,
                reason: "mention",
                repository: {
                    full_name: "muddyblack/gitpulse"
                },
                subject: {
                    title: "Panel margin regression"
                }
            }), Contract.notification({
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
        var p = Contract.profile(userNode);
        eq("stars are summed across repos", p.starsEarned, 139);
        eq("follower count", p.followers, 76);
        eq("commit contributions", p.commits, 22);
        eq("private contributions are surfaced separately", p.privateContributions, 4);
        ok("a null user node does not throw", Contract.profile(null) === null);

        describe("Contract.languages");
        var langs = Contract.languages(userNode, 6);
        eq("most-used language leads", langs[0].name, "Python");
        near("shares are percentages that sum to 100", langs.reduce(function (s, l) {
            return s + l.share;
        }, 0), 100, 0.01);
        eq("colours come from the API", langs[0].color, "#3572A5");
        eq("no repos means no bar rather than a crash", Contract.languages({}, 6).length, 0);

        describe("Contract.calendar");
        function week(counts) {
            return {
                contributionDays: counts.map(function (c, i) {
                    return {
                        date: "2026-01-0" + (i + 1),
                        contributionCount: c,
                        weekday: i
                    };
                })
            };
        }
        var cal = Contract.calendar({
            contributionCalendar: {
                totalContributions: 30,
                weeks: [week([0, 1, 2, 3, 4, 5, 15]), week([0, 0, 0, 0, 0, 0, 0])]
            }
        });
        eq("total is carried through", cal.total, 30);
        eq("two weeks in, two weeks out", cal.weeks.length, 2);
        eq("a quiet day is level 0", cal.weeks[0][0].level, 0);
        eq("the busiest day saturates at level 4", cal.weeks[0][6].level, 4);
        ok("a light day is not level 0", cal.weeks[0][1].level >= 1);
        eq("longest streak counts consecutive active days", cal.streak, 6);
        eq("busiest day is reported", cal.busiest, 15);
        ok("a calendar-less collection returns null", Contract.calendar({}) === null);
        eq("a flat chronological day list is exposed", cal.days.length, 14);
        eq("the last 30 days are sliced out for the trend chart", cal.recent.length, 14);
        eq("the busiest date is reported", cal.busiestDate, "2026-01-07");
        near("the daily average is total over days", cal.average, 30 / 14, 0.01);

        describe("Contract.calendar current streak");
        function calFrom(rows) {
            return Contract.calendar({
                contributionCalendar: {
                    totalContributions: 0,
                    weeks: [week(rows.slice(0, 7)), week(rows.slice(7, 14))]
                }
            });
        }
        eq("counts back from the most recent day", calFrom([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5]).current, 5);
        // Today being quiet must not reset the streak: the day is not over, and
        // a number that flips at midnight is a number nobody trusts.
        eq("a quiet today does not break the streak", calFrom([0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 0]).current, 5);
        eq("two quiet days do break it", calFrom([0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 0, 0, 0, 0]).current, 0);
        eq("an all-quiet year is zero, not NaN", calFrom([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]).current, 0);
        eq("an unbroken run counts every day", calFrom([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]).current, 14);

        describe("Contract.rhythm");
        function at(hour) {
            var d = new Date(2026, 0, 5, hour, 30, 0);
            return {
                created_at: d.toISOString()
            };
        }
        var beat = Contract.rhythm([at(9), at(10), at(11), at(20), at(21), at(2)]);
        eq("buckets are ranked busiest first", beat[0].name, "morning");
        eq("the busiest bucket has its count", beat[0].count, 3);
        near("shares are percentages", beat[0].share, 50, 0.01);
        near("every bucket sums to 100", beat.reduce(function (s, b) {
            return s + b.share;
        }, 0), 100, 0.01);
        eq("late night lands in night, not evening", Contract.rhythm([at(2)])[0].name, "night");
        eq("midday lands in day", Contract.rhythm([at(13)])[0].name, "day");
        eq("no events means no chart rather than a divide by zero", Contract.rhythm([]).length, 0);
        eq("unparseable timestamps are skipped", Contract.rhythm([
            {
                created_at: "nonsense"
            }
        ]).length, 0);

        describe("Contract avatars");
        eq("notifications carry the owner picture", Contract.notification({
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
        eq("a payload without an owner yields an empty string, not undefined", Contract.notification({
            id: "av2",
            unread: true,
            reason: "mention",
            repository: {
                full_name: "a/b"
            },
            subject: {}
        }).avatarUrl, "");

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
