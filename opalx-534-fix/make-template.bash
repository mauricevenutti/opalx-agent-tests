#!/usr/bin/env bash
set -euo pipefail

SRC=~/Documents/MT/opalx_work                    # anpassen: wo OPALX, opalx-manual, regression-tests-x liegen
TPL=~/mt/eval/opalx-534-template
FIX=a5c8592

BASE=$(git -C "$SRC/OPALX" rev-parse "$FIX^")
CUTOFF=$(git -C "$SRC/OPALX" log -1 --format=%cI "$FIX")
echo "Stichtag: $CUTOFF"

snapshot() {   # $1 = Repo-Name, $2 = Commit
  git -C "$SRC/$1" branch -f eval-534 "$2"
  git clone -q --no-local --single-branch --branch eval-534 --no-tags \
      "$SRC/$1" "$TPL/$1"
  git -C "$TPL/$1" remote remove origin
  echo "$1 -> $(git -C "$TPL/$1" log -1 --format='%h %cI %s')"
}

rm -rf "$TPL"; mkdir -p "$TPL"

snapshot OPALX "$BASE"

for r in opalx-manual regression-tests-x; do
  git -C "$SRC/$r" fetch -q origin
  git -C "$SRC/$r" remote set-head origin -a >/dev/null
  C=$(git -C "$SRC/$r" rev-list -1 --before="$CUTOFF" origin/HEAD)
  snapshot "$r" "$C"
done