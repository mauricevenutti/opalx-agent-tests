#!/usr/bin/env bash
set -euo pipefail

# Creates a fresh, isolated working copy for one agent run, starting from
# the shared cutoff-date template (make-template-pr.bash).
# Usage: bash new-agent-run.bash <run-name>
#   e.g. bash new-agent-run.bash sonnet5
#        bash new-agent-run.bash opus5
#        bash new-agent-run.bash gpt5

RUN="${1:?Usage: new-agent-run.bash <run-name>}"
# Paths are relative to the issue folder (the parent of this script's
# folder), whose name is the issue number, e.g. opalx-issues/534/.
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE="$(dirname "$SETUP_DIR")"
ISSUE="$(basename "$BASE")"
TPL="$BASE/opalx-$ISSUE-pr-template"
DEST="$BASE/opalx-$ISSUE-run-$RUN"
BRANCH="$ISSUE-fix-$RUN"

if [ ! -d "$TPL/OPALX" ]; then
  echo "ERROR: template missing at $TPL, run make-template-pr.bash first." >&2
  exit 1
fi

if [ -d "$DEST" ]; then
  echo "ERROR: $DEST already exists." >&2
  exit 1
fi

cp -r "$TPL" "$DEST"

# CMake build trees are not relocatable: CMakeCache.txt and the generated
# Makefiles/compile_commands.json/etc. bake in the absolute path the template
# was built at. Rewrite it to $DEST so the copied build_serial/build_debug
# trees are usable in place, without a reconfigure (which would require
# re-fetching deps over a network this agent is denied). The build path is
# read from CMakeCache.txt rather than assumed to be $TPL, because the
# template may have been moved since it was built.
for build_dir in "$DEST/OPALX"/build_*; do
  [ -f "$build_dir/CMakeCache.txt" ] || continue
  OLD=$(sed -n 's|^CMAKE_CACHEFILE_DIR:INTERNAL=||p' "$build_dir/CMakeCache.txt")
  OLD="${OLD%/OPALX/*}"
  [ -n "$OLD" ] && [ "$OLD" != "$DEST" ] || continue
  LC_ALL=C grep -rlI "$OLD" "$build_dir" 2>/dev/null \
    | xargs -I{} env LC_ALL=C sed -i '' "s|$OLD|$DEST|g" {}
done

# Create the run branch via `gh issue develop` so it is linked to the issue
# on GitHub; any PR opened from it is then linked to the issue automatically.
# This creates the branch on origin from fix-<issue>-sandbox, fetches that
# single ref and checks it out (a plain fetch, no --unshallow, so the
# snapshot stays shallow).
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

# Never let the agent commit the local config, the copied skills or the PR
# body scratch file, regardless of .gitignore.
printf '%s\n' physicscode.json .physicscode/ pr-body.md >> "$DEST/OPALX/.git/info/exclude"

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

# Shared physicscode skills (opalx-build-project, opalx-run-simulation,
# push-fix-to-github) live in opalx-issues/.physicscode/skills. They are
# copied into the checkout's own .physicscode/skills, where physicscode
# finds them without extra config, and the agent can call the push script
# by the short relative path .physicscode/skills/push-fix-to-github/
# push-fix.bash. (With an absolute path outside the project, pai-120b
# failed to run it.) Excluded from commits above, not editable below.
SKILLS_SRC="$(dirname "$BASE")/.physicscode/skills"
if [ ! -f "$SKILLS_SRC/push-fix-to-github/push-fix.bash" ]; then
  echo "ERROR: physicscode skills missing at $SKILLS_SRC (push-fix-to-github is required)." >&2
  exit 1
fi
mkdir -p "$DEST/OPALX/.physicscode"
cp -R "$SKILLS_SRC" "$DEST/OPALX/.physicscode/skills"

# physicscode project config: scope the agent to this run only.
# - project root is $DEST/OPALX (its own .git, correct branch detection)
# - read-only access to the two sibling repos it needs for build/tests
# - everything else outside the project is denied by default (we don't
#   list any other external_directory allow rule)
# - websearch/webfetch denied outright, no need for network access to
#   solve a local issue against a frozen snapshot
# - bash: the last matching rule wins. gh, network git commands and direct
#   pushes are denied, so the agent can neither read other runs' PRs or the
#   original issue/fix nor move fix-<issue>-sandbox. The only way to GitHub
#   is push-fix.bash (the push-fix-to-github skill), whose own gh/git calls
#   are not subject to these rules.
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
echo "  physicscode.json written to $DEST/OPALX (read-only sibling access, no web tools, no gh)"
echo "  Next: bash run-agent.bash $RUN [model], then bash collect-run.bash $RUN"
