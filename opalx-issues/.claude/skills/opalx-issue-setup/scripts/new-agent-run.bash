#!/usr/bin/env bash
set -euo pipefail

# Creates a fresh, isolated working copy for one agent run, from the shared
# cutoff-date template (make-template.bash). Separate copies (not git
# worktrees) so fully parallel agent runs never share a .git, index, or
# refs -- each is independent.
#
# Paths are relative to the issue folder (opalx-issues/<N>/, the parent of
# this script's folder, named after the issue number).
#
# Usage: bash new-agent-run.bash <run-name>
#   Run names must be unique per issue, e.g. sonnet5-01, sonnet5-02,
#   pai-120b-01 (the branch <N>-fix-<run-name> is created on GitHub).

RUN="${1:?Usage: new-agent-run.bash <run-name>}"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE="$(dirname "$SETUP_DIR")"
ISSUE="$(basename "$BASE")"
TPL="$BASE/opalx-$ISSUE-pr-template"
DEST="$BASE/opalx-$ISSUE-run-$RUN"
BRANCH="$ISSUE-fix-$RUN"
# Shared physicscode skills (opalx-build-project, opalx-run-simulation,
# push-fix-to-github), one level above the issue folders.
SKILLS_DIR="$(dirname "$BASE")/.physicscode/skills"

if [ ! -d "$TPL/OPALX" ]; then
  echo "ERROR: template missing at $TPL, run make-template.bash first." >&2
  exit 1
fi
if [ -d "$DEST" ]; then
  echo "ERROR: $DEST already exists." >&2
  exit 1
fi
if [ ! -f "$SKILLS_DIR/push-fix-to-github/push-fix.bash" ]; then
  echo "ERROR: physicscode skills missing at $SKILLS_DIR (push-fix-to-github is required)." >&2
  exit 1
fi

# -p keeps mtimes, so make doesn't consider the copied build stale.
cp -Rp "$TPL" "$DEST"

# CMake build trees are not relocatable: CMakeCache.txt and the generated
# Makefiles/compile_commands.json/etc. bake in the absolute path the
# template was built at. Rewrite it to $DEST so the copied build_* trees are
# usable in place, without a reconfigure (which would re-fetch deps over the
# network). The old path is read from CMakeCache.txt rather than assumed to
# be $TPL, because the template may have been moved since it was built.
for build_dir in "$DEST/OPALX"/build_*; do
  [ -f "$build_dir/CMakeCache.txt" ] || continue
  OLD=$(sed -n 's|^CMAKE_CACHEFILE_DIR:INTERNAL=||p' "$build_dir/CMakeCache.txt")
  OLD="${OLD%/OPALX/*}"
  [ -n "$OLD" ] && [ "$OLD" != "$DEST" ] || continue
  LC_ALL=C grep -rlI -- "$OLD" "$build_dir" 2>/dev/null \
    | while IFS= read -r f; do
        OLD="$OLD" NEW="$DEST" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
      done
done

# Create the run branch via `gh issue develop` so it is linked to the issue
# on GitHub; any PR opened from it is then linked to the issue automatically.
# This creates the branch on origin from fix-<issue>-sandbox, fetches that
# single ref and checks it out (a plain fetch, no --unshallow, so the
# snapshot stays shallow). Fails if the branch name already exists on origin.
TPL_HEAD=$(git -C "$DEST/OPALX" rev-parse HEAD)
( cd "$DEST/OPALX" && gh issue develop "$ISSUE" -R OPALX-project/OPALX \
    --name "$BRANCH" --base "fix-$ISSUE-sandbox" --checkout )

# fix-<issue>-sandbox must point at the template commit, otherwise the agent
# would work on different code than the prebuilt build_* trees (and the
# fetch may have pulled in history past the cutoff).
if [ "$(git -C "$DEST/OPALX" rev-parse HEAD)" != "$TPL_HEAD" ]; then
  echo "ERROR: fix-$ISSUE-sandbox is not at the template commit $TPL_HEAD." >&2
  exit 1
fi

# Never let the agent commit the local config, the PR body scratch file or
# build trees, regardless of what .gitignore looked like at the cutoff.
printf '%s\n' physicscode.json .physicscode/ pr-body.md 'build_*/' >> "$DEST/OPALX/.git/info/exclude"

# Copy the shared skills into the checkout's own .physicscode/skills, where
# physicscode finds them without extra config, and the agent can call the
# push script by the short relative path .physicscode/skills/
# push-fix-to-github/push-fix.bash. (With an absolute path outside the
# project, pai-120b failed to run it.) Excluded from commits above, not
# editable below.
mkdir -p "$DEST/OPALX/.physicscode"
cp -R "$SKILLS_DIR" "$DEST/OPALX/.physicscode/skills"

# Run metadata; run-agent.bash adds model/timing, collect-run.bash reads the
# base commit from here to produce the run's diff.
cat > "$DEST/run-info.json" <<EOF
{
  "issue": $ISSUE,
  "run": "$RUN",
  "branch": "$BRANCH",
  "base_branch": "fix-$ISSUE-sandbox",
  "base_commit": "$TPL_HEAD",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# physicscode project config: scope the agent to this run only.
# - project root is $DEST/OPALX (its own .git, correct branch detection)
# - read-only access to the two sibling repos needed for build/tests
# - everything else outside the project is denied by default
# - websearch/webfetch denied outright: closed-book test against a frozen
#   snapshot
# - bash: the last matching rule wins. gh, network git commands and direct
#   pushes are denied, so parallel runs can neither read each other's PRs
#   or the original issue/fix nor move fix-<issue>-sandbox. The only way to
#   GitHub is push-fix.bash (the push-fix-to-github skill), whose own
#   gh/git calls are not subject to these rules.
# - experimental.continue_loop_on_deny: a denied or auto-rejected tool call
#   (e.g. a write to a mistyped path outside the project) is returned to
#   the agent as an error instead of ending the whole run.
cat > "$DEST/OPALX/physicscode.json" <<EOF
{
  "\$schema": "https://physicscode.ai/config.json",
  "permission": {
    "external_directory": {
      "$DEST/opalx-manual/**": "allow",
      "$DEST/regression-tests-x/**": "allow"
    },
    "read": {
      "$DEST/opalx-manual/**": "allow",
      "$DEST/regression-tests-x/**": "allow"
    },
    "edit": {
      "$DEST/opalx-manual/**": "deny",
      "$DEST/regression-tests-x/**": "deny",
      "$DEST/OPALX/.physicscode/**": "deny",
      ".physicscode/**": "deny"
    },
    "bash": {
      "*": "allow",
      "gh *": "deny",
      "git push*": "deny",
      "git fetch*": "deny",
      "git pull*": "deny",
      "git merge*": "deny",
      "git rebase*": "deny",
      "git remote*": "deny",
      "git ls-remote*": "deny",
      "git clone*": "deny",
      "* --unshallow*": "deny",
      "curl *": "deny",
      "wget *": "deny",
      "*push-fix-to-github/push-fix.bash *": "allow"
    },
    "webfetch": "deny",
    "websearch": "deny"
  }
}
EOF

echo "Ready: $DEST"
echo "  OPALX branch: $BRANCH (origin -> OPALX-project/OPALX, linked to issue #$ISSUE)"
echo "  physicscode.json written (read-only sibling access, no web tools, no gh)"
echo "  Next: bash run-agent.bash $RUN [model], then bash collect-run.bash $RUN"
