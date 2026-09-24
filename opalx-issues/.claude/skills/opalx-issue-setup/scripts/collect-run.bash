#!/usr/bin/env bash
set -euo pipefail

# Collects the results of one finished agent run into results/<run-name>/
# and then deletes the run's working copy (opalx-<issue>-run-<run-name>/,
# several GB of build trees).
#   results/<run>/
#     agent-session-<run>.json / .md   exported transcript (from run-agent.bash)
#     <run>.diff                       everything the agent changed vs. the
#                                      template commit, committed or not
#     meta.json                        run-info.json + head commit, PR, stats
# Usage: bash collect-run.bash <run-name>

RUN="${1:?Usage: collect-run.bash <run-name>}"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE="$(dirname "$SETUP_DIR")"
ISSUE="$(basename "$BASE")"
DEST="$BASE/opalx-$ISSUE-run-$RUN"
OPALX_DIR="$DEST/OPALX"
OUT="$BASE/results/$RUN"
REPO="OPALX-project/OPALX"

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$OPALX_DIR" ] || fail "$OPALX_DIR does not exist."
[ -f "$DEST/run-info.json" ] || fail "$DEST/run-info.json missing (run created before run-info existed?)."
[ ! -e "$OUT" ] || fail "$OUT already exists."
ls "$DEST"/sessions/*.json >/dev/null 2>&1 || fail "no exported session in $DEST/sessions, run run-agent.bash first."

BASE_COMMIT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["base_commit"])' "$DEST/run-info.json")
BRANCH=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["branch"])' "$DEST/run-info.json")

mkdir -p "$OUT"
cp "$DEST"/sessions/* "$OUT/"

# Diff of the working tree against the template commit, so uncommitted and
# untracked files count too (intent-to-add makes untracked files show up).
cd "$OPALX_DIR"
git add -A -N
git diff "$BASE_COMMIT" -- . ':(exclude)physicscode.json' ':(exclude)pr-body.md' > "$OUT/$RUN.diff"
HEAD_COMMIT=$(git rev-parse HEAD)
COMMITS=$(git rev-list --count "$BASE_COMMIT"..HEAD)
UNCOMMITTED=$(git status --porcelain -- . ':(exclude)physicscode.json' ':(exclude)pr-body.md' | wc -l | tr -d ' ')
SHORTSTAT=$(git diff --shortstat "$BASE_COMMIT" -- . ':(exclude)physicscode.json' ':(exclude)pr-body.md')
PUSHED_COMMIT=$(git rev-parse -q --verify "refs/remotes/origin/$BRANCH" || true)
cd "$BASE"

PR_JSON=$(gh pr view -R "$REPO" "$BRANCH" --json url,number,state,title 2>/dev/null || echo '{}')

python3 - "$DEST/run-info.json" "$OUT/meta.json" "$HEAD_COMMIT" "$COMMITS" \
  "$PUSHED_COMMIT" "$UNCOMMITTED" "$SHORTSTAT" "$PR_JSON" <<'PY'
import json, sys
src, dst, head, commits, pushed, uncommitted, stat, pr = sys.argv[1:]
info = json.load(open(src))
info.update(
    head_commit=head,
    commits_ahead=int(commits),
    pushed_commit=pushed or None,
    uncommitted_files=int(uncommitted),
    diffstat=stat.strip(),
    pr=json.loads(pr) or None,
)
json.dump(info, open(dst, "w"), indent=2)
PY

# Only delete the run once everything landed in results/.
[ -s "$OUT/meta.json" ] && ls "$OUT"/*.json "$OUT/$RUN.diff" >/dev/null \
  || fail "collecting into $OUT incomplete, not deleting $DEST."
rm -rf "$DEST"

echo "Collected into $OUT:"
ls -1 "$OUT"
echo "Deleted $DEST"
