#!/usr/bin/env bash
set -euo pipefail
#automated version

# Runs physicscode non-interactively against one agent run's OPALX
# checkout (created earlier by new-agent-run.bash), using
# fix-534-prompt.md as the task. The prompt itself instructs the agent to
# commit, push its branch, and open the PR. Once physicscode exits, this
# script finds the session it just ran, exports the full transcript to
# <run-dir>/sessions/ (a sibling of OPALX/, not inside the git repo) as
# JSON, renders it to Markdown, publishes that Markdown as a gist, and --
# if the agent's PR exists -- comments the gist link onto it.
#
# Usage: bash run-agent.bash <run-name> [model]
#   e.g. bash run-agent.bash pai-120b paidynamics/pai-120b
#        bash run-agent.bash sonnet5

RUN="${1:?Usage: run-agent.bash <run-name> [model]}"
MODEL="${2:-}"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST=~/mt/opalx-534-run-"$RUN"
OPALX_DIR="$DEST/OPALX"
BRANCH="534-fix-$RUN"
PROMPT_FILE=~/mt/fix-534-results/fix-534-prompt.md
TITLE="534-fix-$RUN"

if [ ! -d "$OPALX_DIR" ]; then
  echo "ERROR: $OPALX_DIR does not exist, run new-agent-run.bash $RUN first." >&2
  exit 1
fi

MODEL_ARGS=()
if [ -n "$MODEL" ]; then
  MODEL_ARGS=(--model "$MODEL")
fi

echo "Starting physicscode in $OPALX_DIR (title: $TITLE) ..."
physicscode run \
  --dir "$OPALX_DIR" \
  --title "$TITLE" \
  "${MODEL_ARGS[@]}" \
  "$(cat "$PROMPT_FILE")"

# Find the session that just ran in this directory (there should be
# exactly one per run folder; pick the most recently updated in case of
# reruns). `session list` scopes results to the current working directory's
# project, so it must be run from inside OPALX_DIR, not from wherever this
# script was launched.
SESSION_LIST=$(cd "$OPALX_DIR" && physicscode session list --format json || true)

if [ -z "$SESSION_LIST" ]; then
  echo "WARNING: 'physicscode session list' returned no output, skipping export." >&2
  exit 0
fi

SESSION_ID=$(python3 -c "
import json, sys
try:
    sessions = json.loads(sys.argv[1])
except json.JSONDecodeError as e:
    print(f'WARNING: could not parse session list as JSON: {e}', file=sys.stderr)
    sys.exit(0)
matches = [s for s in sessions if s['directory'] == '$OPALX_DIR']
matches.sort(key=lambda s: s['updated'], reverse=True)
print(matches[0]['id'] if matches else '')
" "$SESSION_LIST")

if [ -z "$SESSION_ID" ]; then
  echo "WARNING: could not find a session for $OPALX_DIR, skipping export." >&2
  exit 0
fi

SESSIONS_DIR="$DEST/sessions"
mkdir -p "$SESSIONS_DIR"

echo "Exporting session $SESSION_ID ..."
JSON_FILE="$SESSIONS_DIR/agent-session-$RUN.json"
MD_FILE="$SESSIONS_DIR/agent-session-$RUN.md"
physicscode export "$SESSION_ID" > "$JSON_FILE"
echo "Saved transcript to $JSON_FILE"

python3 "$SETUP_DIR/session-to-markdown.py" "$JSON_FILE" "$MD_FILE"

GIST_URL=$(gh gist create "$MD_FILE" -d "Agent session transcript ($RUN)" 2>/dev/null || true)
if [ -n "$GIST_URL" ]; then
  echo "Gist created: $GIST_URL"
else
  echo "WARNING: gist creation failed." >&2
fi

PR_URL=$(gh pr view -R OPALX-project/OPALX "$BRANCH" --json url --jq .url 2>/dev/null || true)
if [ -n "$PR_URL" ]; then
  echo "PR found: $PR_URL"
  if [ -n "$GIST_URL" ]; then
    gh pr comment "$PR_URL" -R OPALX-project/OPALX --body "Session: $GIST_URL"
    echo "Commented gist link on PR"
  fi
else
  echo "No open PR found for branch $BRANCH -- the agent may not have opened a PR."
fi
