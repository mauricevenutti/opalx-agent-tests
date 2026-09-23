#!/usr/bin/env bash
set -euo pipefail

# Creates a fresh, isolated working copy for one agent run, starting from
# the shared cutoff-date template (make-template-pr.bash).
# Usage: bash new-agent-run.bash <run-name>
#   e.g. bash new-agent-run.bash sonnet5
#        bash new-agent-run.bash opus5
#        bash new-agent-run.bash gpt5

RUN="${1:?Usage: new-agent-run.bash <run-name>}"
TPL=~/mt/opalx-534-pr-template
DEST=~/mt/opalx-534-run-"$RUN"
BRANCH="534-fix-$RUN"

if [ ! -d "$TPL/OPALX" ]; then
  echo "ERROR: template missing, run make-template-pr.bash first." >&2
  exit 1
fi

if [ -d "$DEST" ]; then
  echo "ERROR: $DEST already exists." >&2
  exit 1
fi

cp -r "$TPL" "$DEST"

# CMake build trees are not relocatable: CMakeCache.txt and the generated
# Makefiles/compile_commands.json/etc. bake in the template's absolute path.
# Rewrite it to $DEST so the copied build_serial/build_test trees are usable
# in place, without a reconfigure (which would require re-fetching deps over
# a network this agent is denied).
for build_dir in "$DEST/OPALX"/build_*; do
  [ -d "$build_dir" ] || continue
  LC_ALL=C grep -rlI "$TPL" "$build_dir" 2>/dev/null \
    | xargs -I{} env LC_ALL=C sed -i '' "s|$TPL|$DEST|g" {}
done

git -C "$DEST/OPALX" checkout -q -b "$BRANCH"

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
      "$DEST/regression-tests-x/**": "deny"
    },
    "webfetch": "deny",
    "websearch": "deny"
  }
}
EOF

echo "Ready: $DEST"
echo "  OPALX branch: $BRANCH (origin -> OPALX-project/OPALX)"
echo "  physicscode.json written to $DEST/OPALX (read-only sibling access, no web tools)"
echo "  Start the agent here, then:"
echo "    git -C $DEST/OPALX push origin $BRANCH"
echo "    gh pr create -R OPALX-project/OPALX --base fix-534-sandbox --head $BRANCH --title ... --body ..."
