#!/usr/bin/env bash
set -euo pipefail

# Commits all changes in the current OPALX checkout, pushes the current
# branch to origin and opens (or updates) the PR against fix-<issue>-sandbox.
# Usage: bash push-fix.bash <issue-number> <pr-title> <pr-body-file>
# Never pulls, fetches, rebases or unshallows: the checkout is a frozen,
# shallow snapshot.

ISSUE="${1:?Usage: push-fix.bash <issue-number> <pr-title> <pr-body-file>}"
TITLE="${2:?Usage: push-fix.bash <issue-number> <pr-title> <pr-body-file>}"
BODY_FILE="${3:?Usage: push-fix.bash <issue-number> <pr-title> <pr-body-file>}"
REPO="OPALX-project/OPALX"
BASE_BRANCH="fix-$ISSUE-sandbox"

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ "$ISSUE" =~ ^[0-9]+$ ]] || fail "issue number must be numeric, got '$ISSUE'."
[ -s "$BODY_FILE" ] || fail "PR body file '$BODY_FILE' is missing or empty."
BODY_FILE="$(cd "$(dirname "$BODY_FILE")" && pwd -P)/$(basename "$BODY_FILE")"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git repository."
cd "$ROOT"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Run branches are named <issue>-fix-<run> (or fix-<issue>-<run>).
[[ "$BRANCH" == "$ISSUE-fix-"* || "$BRANCH" == "fix-$ISSUE-"* ]] && [ "$BRANCH" != "$BASE_BRANCH" ] \
  || fail "current branch '$BRANCH' is not a run branch for issue $ISSUE. Do not switch branches."

# 1. Commit. physicscode.json (the agent's permission config) and the PR body
# file are not part of the fix.
BODY_REL="${BODY_FILE#"$(pwd -P)"/}"
# (Stage-then-unstage: an exclude pathspec naming a gitignored file makes
# `git add` fail.)
git add -A
git reset -q -- physicscode.json "$BODY_REL"
if git diff --cached --quiet; then
  echo "Nothing new to commit, pushing existing commits."
else
  git commit -q -m "$TITLE" -m "Fixes #$ISSUE"
  echo "Committed: $(git log -1 --oneline)"
fi

# 2. Push.
git push origin HEAD
echo "Pushed $BRANCH to origin."

# 3. Open the PR, or update title/body if one already exists for this branch.
EXISTING=$(gh pr view -R "$REPO" "$BRANCH" --json url,state -q 'select(.state=="OPEN") | .url' 2>/dev/null || true)
if [ -n "$EXISTING" ]; then
  gh pr edit -R "$REPO" "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE" >/dev/null
  echo "Updated existing PR."
else
  gh pr create -R "$REPO" --base "$BASE_BRANCH" --head "$BRANCH" \
    --title "$TITLE" --body-file "$BODY_FILE"
fi

# 4. Verify by reading the PR back.
PR_URL=$(gh pr view -R "$REPO" "$BRANCH" --json url -q .url)
PR_BODY=$(gh pr view -R "$REPO" "$BRANCH" --json body -q .body)
[ -n "$PR_BODY" ] || fail "PR $PR_URL has an empty body."
if ! grep -q '@mohsensadr' <<<"$PR_BODY"; then
  echo "WARNING: PR body does not mention @mohsensadr." >&2
fi

# The body now lives in the PR; remove the scratch file.
rm -f "$BODY_FILE"

echo "PR_URL: $PR_URL"
