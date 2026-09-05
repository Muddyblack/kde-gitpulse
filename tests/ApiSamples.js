// Gitpulse — real API payloads, recorded.
//
// The provider tests used payloads written from memory of each API, which
// proves the normalisers are self-consistent and nothing about whether they
// match the forge. These are the real thing:
//
//   · GitLab — captured live from gitlab.com's public endpoints on 2026-09-05.
//     Public projects and users, trimmed to the fields the provider reads
//     plus enough neighbours to catch a rename.
//   · Forgejo — Codeberg is not reachable from the build container, so these
//     are built field-for-field from Gitea's published swagger definitions
//     (templates/swagger/v1-swagger.generated.json), which Forgejo shares.
//     Every key here appears in that spec; none was invented.
//
// If a forge renames or drops a field, the test that reads these fails with
// the field named, instead of the widget quietly rendering a grey "unknown".
.pragma library

// ── GitLab, live ────────────────────────────────────────────────────────────

/** GET /api/v4/projects/:id/pipelines */
var GITLAB_PIPELINE = {
        "id": 2821949521,
        "iid": 6298342,
        "project_id": 278964,
        "sha": "0f3d0220a3443e0e7613419ff6e6b81358a1ee84",
        "ref": "refs/merge-requests/253798/merge",
        "status": "running",
        "source": "merge_request_event",
        "created_at": "2026-09-04T23:36:13.638Z",
        "updated_at": "2026-09-04T23:36:19.133Z",
        "web_url": "https://gitlab.com/gitlab-org/gitlab/-/pipelines/2821949521",
        "name": "Ruby 3.3.12 MR"
    };

/** GET /api/v4/projects?membership=true&order_by=last_activity_at */
var GITLAB_PROJECT = {
        "id": 83793034,
        "name": "SlashyOS",
        "path_with_namespace": "nixos-projects/slashyos",
        "default_branch": "main",
        "web_url": "https://gitlab.com/nixos-projects/slashyos",
        "avatar_url": null,
        "star_count": 0,
        "last_activity_at": "2026-09-04T23:41:03.931Z",
        "visibility": "public",
        "namespace": {
            "id": 96935564,
            "name": "Nixos projects",
            "path": "nixos-projects",
            "avatar_url": null,
            "full_path": "nixos-projects"
        }
    };

/** GET /api/v4/projects/:id/languages — percentages, not bytes. */
var GITLAB_LANGUAGES = {
        "Ruby": 68.14,
        "JavaScript": 20.16,
        "Vue": 7.48,
        "PLpgSQL": 2.02,
        "Haml": 0.9
    };

/** GET /api/v4/users/:id/events — the push variant, which carries commit counts. */
var GITLAB_PUSH_EVENT = {
        "id": 5003131123,
        "project_id": 77645994,
        "action_name": "pushed to",
        "target_id": 77645994,
        "target_iid": 77645994,
        "target_type": "Project",
        "author_id": 1,
        "target_title": "osteosarc.com",
        "created_at": "2026-01-16T18:05:38.864Z",
        "author": {
            "id": 1,
            "username": "sytses",
            "public_email": "",
            "name": "Sid Sijbrandij",
            "state": "active",
            "locked": false,
            "avatar_url": "https://secure.gravatar.com/avatar/adcd204e48241a6528220c7450334cc5ffab2ea1c6a89d3d0ada01d01ed2b49e?s=80&d=identicon",
            "web_url": "https://gitlab.com/sytses"
        },
        "imported": false,
        "imported_from": "none",
        "push_data": {
            "commit_count": 1,
            "action": "pushed",
            "ref_type": "branch",
            "commit_from": "48c3b94aac251977048810d0ac36952f44fb0e02",
            "commit_to": "1b6e129a6e643bde4771f930a9906554fd3cd43d",
            "ref": "main",
            "commit_title": "Edit index.html",
            "ref_count": null
        },
        "author_username": "sytses"
    };

/** GET /users/:name/calendar.json — the endpoint GitLab's own profile uses. */
var GITLAB_CALENDAR = {
        "2025-09-04": 1330,
        "2025-09-05": 1041,
        "2025-09-06": 318,
        "2025-09-07": 210,
        "2025-09-08": 1266,
        "2025-09-09": 1128,
        "2025-09-10": 836,
        "2025-09-11": 1410
    };

/**
 * GET /api/v4/todos — auth-only, so this one is spec-shaped rather than
 * captured. Field names come from GitLab's Todos API documentation.
 */
var GITLAB_TODO = {
    id: 130,
    action_name: "review_requested",
    state: "pending",
    target_type: "MergeRequest",
    created_at: "2026-06-17T07:52:35.225Z",
    updated_at: "2026-06-17T07:52:35.225Z",
    target_url: "https://gitlab.com/group/project/-/merge_requests/7",
    body: "Add a runner image",
    author: {
        id: 12,
        username: "someone",
        name: "Some One",
        avatar_url: "https://gitlab.example/avatar.png"
    },
    project: {
        id: 9,
        name: "project",
        path_with_namespace: "group/project"
    },
    target: {
        id: 77,
        iid: 7,
        title: "Add a runner image",
        state: "opened",
        web_url: "https://gitlab.com/group/project/-/merge_requests/7"
    }
};

// ── Forgejo, from the published API spec ────────────────────────────────────

/**
 * GET /api/v1/notifications → NotificationThread[].
 * Definition fields: id, pinned, repository, subject, unread, updated_at, url.
 * NotificationSubject: html_url, latest_comment_html_url, latest_comment_url,
 * state, title, type, url. Note there is no `reason`.
 */
var FORGEJO_NOTIFICATION = {
    id: 12,
    pinned: false,
    unread: true,
    updated_at: "2026-08-30T09:11:04Z",
    url: "https://codeberg.org/api/v1/notifications/threads/12",
    repository: {
        id: 4,
        full_name: "muddyblack/forgejo-thing",
        owner: {
            login: "muddyblack",
            avatar_url: "https://codeberg.org/avatars/abc"
        }
    },
    subject: {
        title: "Drop the vendored copy",
        type: "Pull",
        state: "open",
        html_url: "https://codeberg.org/muddyblack/forgejo-thing/pulls/3",
        url: "https://codeberg.org/api/v1/repos/muddyblack/forgejo-thing/pulls/3",
        latest_comment_url: ""
    }
};

/**
 * GET /api/v1/repos/{owner}/{repo}/actions/tasks → ActionTaskResponse.
 * Definition: { total_count, workflow_runs: ActionTask[] }.
 *
 * ActionTask fields: created_at, display_title, event, head_branch, head_sha,
 * id, name, run_number, run_started_at, status, updated_at, url, workflow_id.
 * There is no `conclusion`, no `html_url` and no `actor` — the three fields a
 * GitHub-shaped reader would reach for first.
 */
var FORGEJO_TASKS = {
    total_count: 2,
    workflow_runs: [
        {
            id: 91,
            name: "build",
            display_title: "Drop the vendored copy",
            event: "push",
            head_branch: "main",
            head_sha: "0d1c2b3a",
            run_number: 42,
            run_started_at: "2026-08-30T08:59:00Z",
            // The whole conclusion lives in this one string.
            status: "failure",
            created_at: "2026-08-30T08:58:00Z",
            updated_at: "2026-08-30T09:02:00Z",
            url: "https://codeberg.org/muddyblack/forgejo-thing/actions/runs/42",
            workflow_id: "build.yaml"
        },
        {
            id: 92,
            name: "test",
            display_title: "Drop the vendored copy",
            event: "push",
            head_branch: "topic/cleanup",
            head_sha: "0d1c2b3a",
            run_number: 43,
            status: "running",
            created_at: "2026-08-30T09:03:00Z",
            updated_at: "2026-08-30T09:03:00Z",
            url: "https://codeberg.org/muddyblack/forgejo-thing/actions/runs/43",
            workflow_id: "test.yaml"
        }
    ]
};

/** Every status string Forgejo's Status.String() can produce. */
var FORGEJO_STATUSES = ["unknown", "waiting", "running", "success", "failure", "cancelled", "cancelling", "skipped", "blocked"];

/** GET /api/v1/users/{username}/heatmap → UserHeatmapData[]. */
var FORGEJO_HEATMAP = [
    {
        timestamp: 1767268800,
        contributions: 3
    },
    {
        timestamp: 1767355200,
        contributions: 1
    }
];

/** GET /api/v1/user → User. */
var FORGEJO_USER = {
    id: 7,
    login: "muddyblack",
    full_name: "Muddyblack",
    avatar_url: "https://codeberg.org/avatars/abc",
    html_url: "https://codeberg.org/muddyblack",
    description: "information should be free",
    location: "",
    website: "",
    created: "2019-04-02T00:00:00Z",
    followers_count: 12,
    following_count: 4,
    starred_repos_count: 31,
    language: "en-US",
    visibility: "public"
};

/** GET /api/v1/repos/issues/search → Issue[] (the pull-request variant). */
var FORGEJO_PULL = {
    id: 55,
    number: 3,
    title: "Drop the vendored copy",
    state: "open",
    comments: 2,
    created_at: "2026-08-29T10:00:00Z",
    updated_at: "2026-08-30T09:00:00Z",
    html_url: "https://codeberg.org/muddyblack/forgejo-thing/pulls/3",
    url: "https://codeberg.org/api/v1/repos/muddyblack/forgejo-thing/issues/3",
    user: {
        login: "someone",
        avatar_url: "https://codeberg.org/avatars/def"
    },
    assignees: [
        {
            login: "muddyblack"
        }
    ],
    labels: [
        {
            name: "cleanup"
        }
    ],
    repository: {
        id: 4,
        full_name: "muddyblack/forgejo-thing",
        name: "forgejo-thing",
        owner: "muddyblack"
    },
    pull_request: {
        merged: false,
        draft: false,
        html_url: "https://codeberg.org/muddyblack/forgejo-thing/pulls/3"
    }
};

/** GET /api/v1/user/repos → Repository[]. */
var FORGEJO_REPO = {
    id: 4,
    name: "forgejo-thing",
    full_name: "muddyblack/forgejo-thing",
    fork: false,
    stars_count: 9,
    updated_at: "2026-08-30T09:00:00Z",
    default_branch: "main",
    owner: {
        login: "muddyblack",
        avatar_url: "https://codeberg.org/avatars/abc"
    }
};
