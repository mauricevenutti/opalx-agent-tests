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

# Never let the agent commit the local config, regardless of .gitignore.
printf '%s\n' physicscode.json >> "$DEST/OPALX/.git/info/exclude"

# Shared physicscode skills (opalx-build-project, push-fix-to-github) live in
# opalx-issues/.physicscode/skills. physicscode only walks up to the git root
# ($DEST/OPALX) looking for .physicscode/, so they are wired in explicitly
# via skills.paths, readable (the agent runs push-fix.bash from there) but
# not editable.
SKILLS_DIR="$(dirname "$BASE")/.physicscode/skills"

# physicscode project config: scope the agent to this run only.
# - project root is $DEST/OPALX (its own .git, correct branch detection)
# - read-only access to the two sibling repos it needs for build/tests
# - everything else outside the project is denied by default (we don't
#   list any other external_directory allow rule)
# - websearch/webfetch denied outright, no need for network access to
#   solve a local issue against a frozen snapshot
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
echo "  physicscode.json written to $DEST/OPALX (read-only sibling access, no web tools)"
echo "  Start the agent here, then:"
echo "    git -C $DEST/OPALX push origin $BRANCH"
echo "    gh pr create -R OPALX-project/OPALX --base fix-$ISSUE-sandbox --head $BRANCH --title ... --body ..."
