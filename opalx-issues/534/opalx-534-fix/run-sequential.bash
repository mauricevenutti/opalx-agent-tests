#!/usr/bin/env bash
set -uo pipefail

# Runs N agent runs of this issue one after another, all with the same model:
# new-agent-run -> run-agent -> collect-run for each of <prefix>-1..<prefix>-N.
# Each run's output goes to logs/<run>.log in the issue folder.
# Usage: bash run-sequential.bash [count] [model] [prefix] [first-index]
#   defaults: 3 paidynamics/pai-120b pai-120b 1
#   e.g. bash run-sequential.bash 3 paidynamics/pai-120b pai-120b 4  -> pai-120b-4..6

COUNT="${1:-3}"
MODEL="${2:-paidynamics/pai-120b}"
PREFIX="${3:-pai-120b}"
FIRST="${4:-1}"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$(dirname "$SETUP_DIR")/logs"
mkdir -p "$LOG_DIR"

FAILED=0
for i in $(seq "$FIRST" $((FIRST + COUNT - 1))); do
  RUN="$PREFIX-$i"
  LOG="$LOG_DIR/$RUN.log"
  echo "Starting $RUN (log: $LOG) ..."
  if bash "$SETUP_DIR/new-agent-run.bash" "$RUN" > "$LOG" 2>&1 \
     && bash "$SETUP_DIR/run-agent.bash" "$RUN" "$MODEL" >> "$LOG" 2>&1 \
     && bash "$SETUP_DIR/collect-run.bash" "$RUN" >> "$LOG" 2>&1; then
    echo "Done:   $RUN"
  else
    echo "FAILED: $RUN (see $LOG)"
    FAILED=$((FAILED + 1))
  fi
done

echo "$((COUNT - FAILED))/$COUNT runs finished and collected."
[ "$FAILED" -eq 0 ]
