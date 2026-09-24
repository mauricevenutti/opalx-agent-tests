#!/usr/bin/env bash
set -euo pipefail

# Downloads a real OPALX issue (body + comments) and the diff of the PR
# that resolved it. This is the ground truth for an agent study: the
# agent must never see fix-<N>.diff (and usually not issue-<N>.md verbatim
# either -- OPALX issues often already name the root cause).
#
# Writes:
#   issue-<N>.md     issue title, url, body and all comments
#   fix-<N>.pr       number of the resolving PR
#   fix-<N>.commit   full SHA of the commit that landed the fix on the base
#                    branch (merge commit, squash commit, or last rebased
#                    commit, depending on how the PR was merged)
#   fix-<N>.base     full SHA of the last commit on the base branch
#                    *before* any of the fix landed -- the snapshot the
#                    agent starts from (make-template.bash)
#   fix-<N>.diff     the PR diff
#
# All files go to results/original/ in the issue folder
# (opalx-issues/<N>/, the parent of this script's folder, named after the
# issue number).
#
# Usage: bash fetch-issue.bash [pr-number]
#   pr-number overrides the automatic lookup (needed when the issue was
#   closed without a linked PR, or when the lookup picks the wrong one).

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$(dirname "$SETUP_DIR")"
ISSUE="$(basename "$BASE_DIR")"
PR="${1:-}"
OUT="$BASE_DIR/results/original"
mkdir -p "$OUT"
ORG=OPALX-project
REPO=OPALX

echo "Fetching issue #$ISSUE ..."
gh issue view "$ISSUE" -R "$ORG/$REPO" --json number,title,body,url,state,comments \
  --jq '"# #\(.number): \(.title)\n\n\(.url) (\(.state))\n\n\(.body)"
        + ([.comments[] | "\n\n---\n\n**Comment by @\(.author.login)** (\(.createdAt)):\n\n\(.body)"] | join(""))' \
  > "$OUT/issue-$ISSUE.md"

if [ -z "$PR" ]; then
  echo "Looking for the PR that closed issue #$ISSUE ..."
  # Primary source: GitHub's own "closed by" link (PRs with "Fixes #N" or
  # linked via the Development sidebar). The timeline's cross-reference
  # events are only a fallback -- they miss linked PRs that never mention
  # the issue in text, and also list unrelated PRs that merely mention it.
  CANDIDATES=$(gh issue view "$ISSUE" -R "$ORG/$REPO" --json closedByPullRequestsReferences \
    --jq '.closedByPullRequestsReferences[].number' 2>/dev/null || true)
  if [ -z "$CANDIDATES" ]; then
    CANDIDATES=$(gh api --paginate "repos/$ORG/$REPO/issues/$ISSUE/timeline?per_page=100" \
      --jq '.[] | select(.event=="cross-referenced"
                          and .source.issue.pull_request.merged_at != null
                          and .source.issue.repository.full_name == "'"$ORG/$REPO"'")
                | .source.issue.number')
  fi

  # Keep only merged PRs in this repo; if several, take the most recently
  # merged one. (A closedBy PR from a fork/other repo 404s here and is
  # skipped.)
  MERGED=""
  for c in $CANDIDATES; do
    m=$(gh api "repos/$ORG/$REPO/pulls/$c" --jq 'select(.merged) | "\(.merged_at) \(.number)"' 2>/dev/null || true)
    [ -n "$m" ] && MERGED+="$m"$'\n'
  done
  MERGED=$(printf '%s' "$MERGED" | sort -u)
  if [ -z "$MERGED" ]; then
    echo "ERROR: could not find a merged PR that resolved issue #$ISSUE." >&2
    echo "Find it manually on GitHub and re-run: bash fetch-issue.bash <pr-number>" >&2
    exit 1
  fi
  if [ "$(printf '%s\n' "$MERGED" | wc -l)" -gt 1 ]; then
    echo "WARNING: several merged PRs are linked to #$ISSUE:" >&2
    printf '%s\n' "$MERGED" | awk '{print "  PR #" $2 " (merged " $1 ")"}' >&2
    echo "  Using the most recently merged one; pass a PR number to override." >&2
  fi
  PR=$(printf '%s\n' "$MERGED" | tail -1 | awk '{print $2}')
fi

read -r MERGED_FLAG BASE_REF SHA NCOMMITS < <(gh api "repos/$ORG/$REPO/pulls/$PR" \
  --jq '"\(.merged) \(.base.ref) \(.merge_commit_sha) \(.commits)"')
if [ "$MERGED_FLAG" != "true" ]; then
  echo "ERROR: PR #$PR is not merged." >&2
  exit 1
fi
DEFAULT_BRANCH=$(gh api "repos/$ORG/$REPO" --jq .default_branch)
if [ "$BASE_REF" != "$DEFAULT_BRANCH" ]; then
  echo "WARNING: PR #$PR was merged into '$BASE_REF', not '$DEFAULT_BRANCH'." >&2
  echo "  The snapshot will be '$BASE_REF' right before the fix." >&2
fi

# Find the commit right before the fix landed on the base branch:
# - merge commit (2 parents): its first parent
# - squash merge (1 parent):  its parent
# - rebase merge (1 parent, PR had several commits): walk back first
#   parents while the commit still belongs to this PR, so no rebased
#   fix commit ends up in the snapshot.
read -r NPARENTS BASE < <(gh api "repos/$ORG/$REPO/commits/$SHA" \
  --jq '"\(.parents | length) \(.parents[0].sha)"')
if [ "$NPARENTS" = "1" ] && [ "$NCOMMITS" -gt 1 ]; then
  for _ in $(seq 2 "$NCOMMITS"); do
    in_pr=$(gh api "repos/$ORG/$REPO/commits/$BASE/pulls" --jq "[.[].number] | index($PR) != null")
    [ "$in_pr" = "true" ] || break
    BASE=$(gh api "repos/$ORG/$REPO/commits/$BASE" --jq '.parents[0].sha')
  done
fi

echo "$PR"   > "$OUT/fix-$ISSUE.pr"
echo "$SHA"  > "$OUT/fix-$ISSUE.commit"
echo "$BASE" > "$OUT/fix-$ISSUE.base"

echo "Fetching diff of PR #$PR ..."
gh pr diff "$PR" -R "$ORG/$REPO" > "$OUT/fix-$ISSUE.diff"

echo "Done:"
echo "  $OUT/issue-$ISSUE.md   (issue + comments -- basis for the hand-written prompt)"
echo "  $OUT/fix-$ISSUE.diff   (ground truth, PR #$PR -- never show this to the agent)"
echo "  $OUT/fix-$ISSUE.commit ($SHA, fix landed on $BASE_REF)"
echo "  $OUT/fix-$ISSUE.base   ($BASE, snapshot the agent starts from)"
