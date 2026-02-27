#!/bin/bash
# bump_version.sh — Determine and apply semantic version bump for an algorithm.
#
# Usage: bash scripts/bump_version.sh <algorithm_name>
#
# Analyzes conventional commit messages since the last tag to determine
# the bump type (major/minor/patch), updates VERSION and CHANGELOG,
# creates a git tag.

source "$(dirname "$0")/common.sh"

ALGO="${1:?Usage: bump_version.sh <algorithm_name>}"
VERSION_FILE="${REPO_ROOT}/algorithms/${ALGO}/VERSION"
CHANGELOG_FILE="${REPO_ROOT}/algorithms/${ALGO}/CHANGELOG.md"

validate_algorithm "$ALGO"

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
log_info "Current version for $ALGO: $CURRENT_VERSION"

# Find commits since last tag for this algorithm
LAST_TAG=$(git -C "$REPO_ROOT" tag -l "${ALGO}/v*" --sort=-version:refname | head -1)
if [ -z "$LAST_TAG" ]; then
    log_info "No previous tag found. This is the first release."
    COMMIT_RANGE="HEAD"
    COMMITS=$(git -C "$REPO_ROOT" log --oneline -- "algorithms/${ALGO}/")
else
    COMMIT_RANGE="${LAST_TAG}..HEAD"
    COMMITS=$(git -C "$REPO_ROOT" log "${COMMIT_RANGE}" --oneline -- "algorithms/${ALGO}/")
fi

if [ -z "$COMMITS" ]; then
    log_info "No new commits for $ALGO since $LAST_TAG. Skipping version bump."
    echo "$CURRENT_VERSION" > "${WORKSPACE}/results/${ALGO}/new_version.txt"
    exit 0
fi

# Analyze commit messages for version bump type
BUMP="patch"
while IFS= read -r line; do
    msg=$(echo "$line" | cut -d' ' -f2-)

    # BREAKING CHANGE or ! after type -> major
    if echo "$msg" | grep -qiE '^[a-z]+(\(.+\))?!:|BREAKING CHANGE'; then
        BUMP="major"
        break
    fi

    # feat -> minor
    if echo "$msg" | grep -qiE '^feat(\(.+\))?:'; then
        if [ "$BUMP" != "major" ]; then
            BUMP="minor"
        fi
    fi
done <<< "$COMMITS"

# Check for API signature changes (elevate to at least minor)
PREV_SIGS="${WORKSPACE}/.cache/previous_builds/${ALGO}/api_signatures.txt"
CURR_SIGS="${WORKSPACE}/results/${ALGO}/api_signatures.txt"
if [ -f "$PREV_SIGS" ] && [ -f "$CURR_SIGS" ]; then
    if ! diff -q "$PREV_SIGS" "$CURR_SIGS" &>/dev/null; then
        log_info "API signatures changed — elevating bump to at least MINOR"
        if [ "$BUMP" = "patch" ]; then
            BUMP="minor"
        fi
    fi
fi

# Apply bump
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

log_info "Version bump: $CURRENT_VERSION -> $NEW_VERSION ($BUMP)"

# Update VERSION file
echo "$NEW_VERSION" > "$VERSION_FILE"

# Update CHANGELOG
DATE=$(date +%Y-%m-%d)
CHANGELOG_ENTRY="## ${NEW_VERSION} (${DATE})\n\n"
while IFS= read -r line; do
    CHANGELOG_ENTRY+="- ${line}\n"
done <<< "$COMMITS"
CHANGELOG_ENTRY+="\n"

if [ -f "$CHANGELOG_FILE" ]; then
    # Insert after the header line
    EXISTING=$(cat "$CHANGELOG_FILE")
    {
        echo "# Changelog — ${ALGO}"
        echo ""
        echo -e "$CHANGELOG_ENTRY"
        # Append everything after the first header
        echo "$EXISTING" | tail -n +3
    } > "$CHANGELOG_FILE"
else
    {
        echo "# Changelog — ${ALGO}"
        echo ""
        echo -e "$CHANGELOG_ENTRY"
    } > "$CHANGELOG_FILE"
fi

# Stage changes and create tag
git -C "$REPO_ROOT" add "$VERSION_FILE" "$CHANGELOG_FILE"
git -C "$REPO_ROOT" commit -m "chore(${ALGO}): bump version to ${NEW_VERSION} [skip ci]"
git -C "$REPO_ROOT" tag "${ALGO}/v${NEW_VERSION}"

# Write new version for downstream stages
mkdir -p "${WORKSPACE}/results/${ALGO}"
echo "$NEW_VERSION" > "${WORKSPACE}/results/${ALGO}/new_version.txt"

log_info "Tagged: ${ALGO}/v${NEW_VERSION}"
