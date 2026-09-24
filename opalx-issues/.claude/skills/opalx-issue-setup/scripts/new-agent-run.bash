#!/usr/bin/env bash
set -euo pipefail

# Creates a fresh, isolated working copy for one agent run, from the shared
# cutoff-date template (make-template.bash). Single-run setup: the agent
# keeps gh access (it verifies its own PR with gh pr view).
#
# Paths are relative to the issue folder (opalx-issues/<N>/, the parent of
# this script's folder, named after the issue number).
#
# Usage: bash new-agent-run.bash <run-name>
#   e.g. bash new-agent-run.bash sonnet5
#   (the branch <N>-fix-<run-name> is created on GitHub, so the name must
#   not exist there yet).

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

# Never let the agent commit the local config or build trees, regardless of
# what .gitignore looked like at the cutoff.
printf '%s\n' physicscode.json 'build_*/' >> "$DEST/OPALX/.git/info/exclude"

# physicscode project config: scope the agent to this run only.
# - project root is $DEST/OPALX (its own .git, correct branch detection)
# - read-only access to the two sibling repos needed for build/tests
# - skills: physicscode only walks up to the git root ($DEST/OPALX) looking
#   for .physicscode/, so the shared skills are wired in via skills.paths,
#   readable (the agent runs push-fix.bash from there) but not editable
# - everything else outside the project is denied by default
# - websearch/webfetch denied outright: closed-book test against a frozen
#   snapshot
cat > "$DEST/OPALX/physicscode.json" <<EOF
{
  "\$schema": "https://physicscode.ai/config.json",
  "skills": {
    "paths": ["$SKILLS_DIR"]
  },
  "permission": {
    "external_directory": {
      "$DEST/opalx-manual/**": "allow",
      "$DEST/regression-tests-x/**": "allow",
      "$SKILLS_DIR/**": "allow"
    },
    "read": {
      "$DEST/opalx-manual/**": "allow",
      "$DEST/regression-tests-x/**": "allow",
      "$SKILLS_DIR/**": "allow"
    },
    "edit": {
      "$DEST/opalx-manual/**": "deny",
      "$DEST/regression-tests-x/**": "deny",
      "$SKILLS_DIR/**": "deny"
    },
    "webfetch": "deny",
    "websearch": "deny"
  }
}
EOF

echo "Ready: $DEST"
echo "  OPALX branch: $BRANCH (origin -> OPALX-project/OPALX, linked to issue #$ISSUE)"
echo "  physicscode.json written (read-only sibling access, no web tools)"
echo "  Next: bash run-agent.bash $RUN [model]"
