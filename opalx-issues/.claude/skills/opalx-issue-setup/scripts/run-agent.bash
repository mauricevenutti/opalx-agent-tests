#!/usr/bin/env bash
set -euo pipefail

# Runs physicscode non-interactively for one agent run, feeding it
# <issue>-prompt.md (in the issue folder) as the task message directly in
# the run's OPALX checkout. The prompt must tell the agent to deliver via
# the push-fix-to-github skill (commit, push, PR against
# fix-<issue>-sandbox); the agent itself has no gh access. Records model
# and wall-clock time in run-info.json. Once physicscode exits, this script
# finds the session it just ran, exports the full transcript to
# <run-dir>/sessions/ (a sibling of OPALX/, not inside the git repo) as
# JSON, renders it to Markdown, publishes that Markdown as a gist, and --
# if the agent's PR exists -- comments the gist link onto it.
#
# Paths are relative to the issue folder (opalx-issues/<N>/, the parent of
# this script's folder, named after the issue number).
#
# Usage: bash run-agent.bash <run-name> [model]
#   e.g. bash run-agent.bash pai-120b-01 paidynamics/pai-120b
#        bash run-agent.bash sonnet5-01

RUN="${1:?Usage: run-agent.bash <run-name> [model]}"
MODEL="${2:-}"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE="$(dirname "$SETUP_DIR")"
ISSUE="$(basename "$BASE")"
DEST="$BASE/opalx-$ISSUE-run-$RUN"
OPALX_DIR="$DEST/OPALX"
BRANCH="$ISSUE-fix-$RUN"
PROMPT_FILE="$BASE/$ISSUE-prompt.md"
TITLE="$ISSUE-fix-$RUN"

if [ ! -d "$OPALX_DIR" ]; then
  echo "ERROR: $OPALX_DIR missing, run new-agent-run.bash $RUN first." >&2
  exit 1
fi
if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: $PROMPT_FILE missing -- write the agent's task prompt first." >&2
  exit 1
fi

MODEL_ARGS=()
if [ -n "$MODEL" ]; then
  MODEL_ARGS=(--model "$MODEL")
fi

echo "Starting physicscode in $OPALX_DIR (title: $TITLE) ..."
# ${arr[@]+...}: an empty array under `set -u` is an "unbound variable"
# error in macOS's bash 3.2. A non-zero exit (crash, timeout, Ctrl-C) must
# not skip the transcript export below.
# Hide Claude Code skills (~/.claude/skills, e.g. opalx-issue-setup, which
# fetches the original issue and fix); the agent only gets the skills wired
# in via physicscode.json.
STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_S=$(date +%s)
EXIT_STATUS=0
PHYSICSCODE_DISABLE_CLAUDE_CODE_SKILLS=1 physicscode run \
  --dir "$OPALX_DIR" \
  --title "$TITLE" \
  ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  "$(cat "$PROMPT_FILE")" || EXIT_STATUS=$?
END_S=$(date +%s)

# Record model and wall-clock time in run-info.json (read by collect-run.bash).
python3 - "$DEST/run-info.json" "$MODEL" "$STARTED" "$((END_S - START_S))" "$EXIT_STATUS" <<'PY'
import json, os, sys
path, model, started, seconds, status = sys.argv[1:]
info = json.load(open(path)) if os.path.exists(path) else {}
info.update(model=model or "default", started=started,
            duration_s=int(seconds), exit_status=int(status))
json.dump(info, open(path, "w"), indent=2)
PY
[ "$EXIT_STATUS" -eq 0 ] || echo "WARNING: physicscode exited with status $EXIT_STATUS, exporting the session anyway." >&2

# Find the session that just ran in this directory (there should be
# exactly one per run folder; pick the most recently updated in case of
# reruns). `session list` scopes results to the current working
# directory's project, so it must be run from inside OPALX_DIR, not from
# wherever this script was launched.
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
matches = [s for s in sessions if s.get('directory') == '$OPALX_DIR']
matches.sort(key=lambda s: s.get('updated', 0), reverse=True)
print(matches[0]['id'] if matches else '')
" "$SESSION_LIST")

if [ -z "$SESSION_ID" ]; then
  echo "WARNING: could not find a session for $OPALX_DIR, skipping export." >&2
  exit 0
fi

# Note: deliberately not using `physicscode export --sanitize` -- it
# redacts every text, reasoning, and diff part wholesale (replacing them
# with placeholders like "[redacted:text:...]"), which makes the export
# useless for actually reviewing what the agent did. Since the transcript
# stays local under sessions/ and is never pushed, there's no need for
# sanitization.
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
    gh pr comment "$PR_URL" -R OPALX-project/OPALX --body "Detailed Session: $GIST_URL"
    echo "Commented gist link on PR"
  fi
else
  echo "No open PR found for branch $BRANCH -- the agent may not have opened a PR."
fi
