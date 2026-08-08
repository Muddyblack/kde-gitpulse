#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

BETA_FLAG=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --beta)
            BETA_FLAG=true
            shift
            ;;
        *)
            echo "Usage: $0 [--beta]" >&2
            exit 1
            ;;
    esac
done

METADATA_FILE="$HERE/package/metadata.json"

if [ ! -f "$METADATA_FILE" ]; then
    echo "Error: package/metadata.json not found!" >&2
    exit 1
fi

cd "$HERE"

# ── helpers ───────────────────────────────────────────────────────────────────

# Files that pre-commit auto-fixed: unstaged changes on paths that are still staged.
# Does NOT pick up other dirty/untracked files outside the commit.
hook_fixed_files() {
    local staged unstaged
    staged="$(git diff --cached --name-only --diff-filter=ACMR | sort -u)"
    unstaged="$(git diff --name-only | sort -u)"
    if [[ -z "$staged" || -z "$unstaged" ]]; then
        return 0
    fi
    comm -12 <(printf '%s\n' "$staged") <(printf '%s\n' "$unstaged")
}

# Commit once; if hooks rewrote staged files, optionally stage only those fixes and retry.
# Reuses the same commit message — no re-prompt for bump / message.
git_commit_with_hook_retry() {
    local commit_msg="$1"
    local max_attempts="${2:-3}"
    local attempt=1
    local rc=0
    local fixed
    local retry_choice
    local f

    while (( attempt <= max_attempts )); do
        set +e
        git commit -m "$commit_msg"
        rc=$?
        set -e

        if [[ $rc -eq 0 ]]; then
            return 0
        fi

        fixed="$(hook_fixed_files || true)"
        if [[ -z "$fixed" ]]; then
            echo "" >&2
            echo "Commit failed (exit $rc). No hook auto-fixes detected on staged files." >&2
            echo "Fix the reported issues, then re-run. Version bump (if any) is already in metadata.json." >&2
            return "$rc"
        fi

        echo ""
        echo "Pre-commit hooks modified these staged files:"
        while IFS= read -r f; do
            [[ -n "$f" ]] && printf '  %s\n' "$f"
        done <<< "$fixed"
        echo ""

        if (( attempt >= max_attempts )); then
            echo "Still failing after ${max_attempts} attempts. Not retrying again." >&2
            return "$rc"
        fi

        # Default yes — Enter continues without restarting the whole tag flow.
        read -rp "Stage only these hook fixes and retry commit? [Y/n]: " retry_choice
        if [[ "$retry_choice" =~ ^[Nn]$ ]]; then
            echo "Aborting. Staged release changes are left as-is; metadata version may already be bumped."
            return 1
        fi

        while IFS= read -r f; do
            [[ -n "$f" ]] && git add -- "$f"
        done <<< "$fixed"

        attempt=$((attempt + 1))
        echo "Retrying commit (attempt ${attempt}/${max_attempts})..."
        echo ""
    done

    return "$rc"
}

# ── version bump ─────────────────────────────────────────────────────────────
CURRENT_VERSION="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$METADATA_FILE" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"

# Split into numeric part and optional suffix (e.g. "0.0.2-beta" → "0.0.2" + "-beta")
NUMERIC="${CURRENT_VERSION%%-*}"
if [[ "$CURRENT_VERSION" == *-* ]]; then
    CURRENT_SUFFIX="-${CURRENT_VERSION#*-}"
else
    CURRENT_SUFFIX=""
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$NUMERIC"

echo "Current version: ${CURRENT_VERSION}"
echo ""
echo "Bump type:"
echo "  [p] patch  → ${MAJOR}.${MINOR}.$((PATCH + 1))${CURRENT_SUFFIX}"
echo "  [m] minor  → ${MAJOR}.$((MINOR + 1)).0${CURRENT_SUFFIX}"
echo "  [M] major  → $((MAJOR + 1)).0.0${CURRENT_SUFFIX}"
echo "  [k] keep   → ${CURRENT_VERSION}"
read -rp "Choice [p/m/M/k]: " bump_choice

case "$bump_choice" in
    m) NEW_NUMERIC="${MAJOR}.$((MINOR + 1)).0" ;;
    M) NEW_NUMERIC="$((MAJOR + 1)).0.0" ;;
    k) NEW_NUMERIC="$NUMERIC" ;;
    *) NEW_NUMERIC="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;  # default: patch
esac

if [[ "$BETA_FLAG" == true ]]; then
    NEW_SUFFIX="-beta"
elif [[ -n "$CURRENT_SUFFIX" ]]; then
    echo ""
    read -rp "Remove beta suffix? [y/N]: " remove_beta
    if [[ "$remove_beta" =~ ^[Yy]$ ]]; then
        NEW_SUFFIX=""
    else
        NEW_SUFFIX="$CURRENT_SUFFIX"
    fi
else
    NEW_SUFFIX=""
fi

NEW_VERSION="${NEW_NUMERIC}${NEW_SUFFIX}"
TAG_NAME="v${NEW_VERSION}"

echo ""

# Write new version to metadata.json
sed -i "s/\"Version\": \"${CURRENT_VERSION}\"/\"Version\": \"${NEW_VERSION}\"/" "$METADATA_FILE"
echo "Updated metadata.json → ${NEW_VERSION}"

# ── commit, tag, push ─────────────────────────────────────────────────────────
if ! git diff-index --quiet HEAD --; then
    echo ""
    read -rp "Commit message (default: 'chore: release ${TAG_NAME}'): " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="chore: release ${TAG_NAME}"
    fi
    git add .
    git_commit_with_hook_retry "$commit_msg"
fi

# Check the fully qualified ref so this lookup cannot match a branch or other
# ref with the same version name.
if git rev-parse --verify --quiet "refs/tags/${TAG_NAME}" >/dev/null
then
    echo "Warning: Tag ${TAG_NAME} already exists."
    read -rp "Overwrite? [y/N]: " recreate_tag
    if [[ "$recreate_tag" =~ ^[Yy]$ ]]; then
        git tag -d "$TAG_NAME"
        git push origin --delete "$TAG_NAME" || true
    else
        echo "Aborting."
        exit 0
    fi
fi

echo "Creating tag ${TAG_NAME}..."
git tag -a "$TAG_NAME" -m "Release ${TAG_NAME}"

CURRENT_BRANCH="$(git branch --show-current)"
echo "Pushing branch '${CURRENT_BRANCH}' and tag '${TAG_NAME}' to remote..."
git push origin "$CURRENT_BRANCH"
git push origin "$TAG_NAME"

echo ""
echo "=== Tagged ${TAG_NAME} and pushed. CI will build the .plasmoid and create the GitHub release. ==="
