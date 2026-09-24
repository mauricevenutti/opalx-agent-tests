#!/usr/bin/env bash
set -euo pipefail

# Builds a frozen, cutoff-date snapshot of OPALX + opalx-manual +
# regression-tests-x at the commit right before the fix for <issue-number>,
# so an agent working from it cannot see the real fix or any later
# history. OPALX keeps a real origin remote (so agent runs can later push
# a fix branch and open a PR); the other two repos are origin-less
# snapshots needed only for building/testing.
#
# Every fetch is a shallow fetch of one exact commit SHA (never a branch
# tip), so no commit objects from after the cutoff ever land locally --
# not even unreachable ones -- and git log/git log --all/FETCH_HEAD/reflog
# cannot leak later history to the agent.
#
# Also pushes a "fix-<issue-number>-sandbox" branch to the real repo, from
# the same cutoff commit, to use as the PR base for all agent runs on this
# issue (so their PRs don't clutter the real PR queue against master).
#
# Finally configures and builds OPALX twice (build_serial and build_debug,
# Debug, SERIAL, unit tests ON), so agent runs copied from this template
# start from a warm build instead of rebuilding from scratch every time.
#
# Paths are relative to the issue folder (opalx-issues/<N>/, the parent of
# this script's folder, named after the issue number). The template goes
# to opalx-<N>-pr-template/ there.
#
# Usage: bash make-template.bash [fix-commit-sha]
#   fix-commit-sha (short or full) overrides results/original/fix-<N>.commit
#   and fix-<N>.base (written by fetch-issue.bash); the snapshot is then
#   its first parent.

ORG=OPALX-project
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ISSUE_DIR="$(dirname "$SETUP_DIR")"
ISSUE="$(basename "$ISSUE_DIR")"
ORIG="$ISSUE_DIR/results/original"
TPL="$ISSUE_DIR/opalx-$ISSUE-pr-template"

# GitHub only serves "unadvertised" commits by their full 40-char SHA, so
# resolve everything through the API first.
if [ -n "${1:-}" ]; then
  FIX=$(gh api "repos/$ORG/OPALX/commits/$1" --jq '.sha')
  BASE=$(gh api "repos/$ORG/OPALX/commits/$FIX" --jq '.parents[0].sha')
else
  for f in commit base; do
    if [ ! -f "$ORIG/fix-$ISSUE.$f" ]; then
      echo "ERROR: $ORIG/fix-$ISSUE.$f missing -- run fetch-issue.bash first, or pass a commit sha." >&2
      exit 1
    fi
  done
  FIX=$(cat "$ORIG/fix-$ISSUE.commit")
  BASE=$(cat "$ORIG/fix-$ISSUE.base")
fi
# Cutoff for the sibling repos: when the fix landed on OPALX.
CUTOFF=$(gh api "repos/$ORG/OPALX/commits/$FIX" --jq '.commit.committer.date')

rm -rf "$TPL"; mkdir -p "$TPL"

# --- OPALX: keeps origin, for the later agent push/PR --------------------
BASE_DIR="$TPL/OPALX"
mkdir -p "$BASE_DIR"
git -C "$BASE_DIR" init -q
git -C "$BASE_DIR" remote add origin "https://github.com/$ORG/OPALX.git"
git -C "$BASE_DIR" fetch -q origin "$BASE" --depth 1
git -C "$BASE_DIR" checkout -q -b eval-"$ISSUE" FETCH_HEAD
echo "Cutoff: $CUTOFF"
echo "OPALX -> $(git -C "$BASE_DIR" log -1 --format='%h %cI %s')"

# --- opalx-manual, regression-tests-x: origin-less snapshots --------------
clone_snapshot() {   # $1 = repo name
  local repo="$1" dir="$TPL/$1" branch c
  branch=$(gh api "repos/$ORG/$repo" --jq .default_branch)
  c=$(gh api "repos/$ORG/$repo/commits?sha=$branch&until=$CUTOFF&per_page=1" --jq '.[0].sha')
  if [ -z "$c" ] || [ "$c" = "null" ]; then
    echo "ERROR: no commit before $CUTOFF in $repo on $branch" >&2
    exit 1
  fi

  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "https://github.com/$ORG/$repo.git"
  git -C "$dir" fetch -q origin "$c" --depth 1
  git -C "$dir" checkout -q FETCH_HEAD -b eval-"$ISSUE"
  git -C "$dir" remote remove origin
  echo "$repo -> $(git -C "$dir" log -1 --format='%h %cI %s')"
}

clone_snapshot opalx-manual
clone_snapshot regression-tests-x

# --- sandbox base branch on the real repo --------------------------------
SANDBOX_BRANCH="fix-$ISSUE-sandbox"
if git -C "$BASE_DIR" ls-remote --exit-code origin "refs/heads/$SANDBOX_BRANCH" >/dev/null 2>&1; then
  echo "Sandbox base branch already exists on origin: $SANDBOX_BRANCH (left as is)"
else
  git -C "$BASE_DIR" push -q origin "eval-$ISSUE:refs/heads/$SANDBOX_BRANCH"
  echo "Sandbox base branch pushed: $SANDBOX_BRANCH"
fi

# --- build once (twice) ----------------------------------------------------
# build_serial is the tree the prompt/build skill points agents at.
# build_debug is prebuilt as well because agents sometimes ignore the
# build skill's advice to repair a relocated build_serial and create a
# fresh "build_debug" instead -- which would otherwise rebuild
# IPPL/Kokkos/heFFTe/HDF5 from scratch.
# A failed build is not fatal: the snapshot itself is still valid (older
# cutoffs may need other CMake options); it just means agents start cold.
NPROC=$(sysctl -n hw.ncpu 2>/dev/null || nproc)
build() {   # $1 = build dir name, rest = extra cmake options
  local dir="$BASE_DIR/$1"; shift
  echo "Building OPALX in the template as $(basename "$dir") (can take 10+ minutes) ..."
  if cmake -S "$BASE_DIR" -B "$dir" \
        -DBUILD_TYPE=Debug \
        -DPLATFORMS=SERIAL \
        -DOPALX_ENABLE_UNIT_TESTS=ON \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@" \
     && cmake --build "$dir" -j "$NPROC"; then
    echo "Build done -> $dir"
  else
    echo "WARNING: building $dir failed -- template is usable, but agents will start without a warm build." >&2
  fi
}
build build_serial -DOPALX_ENABLE_TESTS=ON
build build_debug
