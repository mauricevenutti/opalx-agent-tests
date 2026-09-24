#!/usr/bin/env bash
set -euo pipefail

# Wie make-template.bash, aber:
# - klont direkt von GitHub (OPALX-project), nicht von lokalen Repos
# - OPALX behaelt ein echtes origin-Remote, damit der Agent am Ende
#   pushen und einen PR eroeffnen kann
# - alle drei Repos sind Snapshots auf dem Stichtag: jeder Clone wird als
#   shallow fetch genau des passenden Commits erzeugt, damit NIE
#   Commit-Objekte von nach dem Stichtag lokal landen (auch nicht
#   unreachable im .git) -> Agent kann ueber git log/git log --all/
#   FETCH_HEAD/reflog keine spaetere Historie sehen.

# Paths are relative to the issue folder (the parent of this script's
# folder), whose name is the issue number, e.g. opalx-issues/534/.
BASE="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)")"
ISSUE="$(basename "$BASE")"
TPL="$BASE/opalx-$ISSUE-pr-template"
ORG=OPALX-project

# GitHub verlangt fuer den Fetch eines "unadvertised" Commits den vollen
# 40-Zeichen-SHA, die Kurzform reicht nicht.
FIX=$(gh api "repos/$ORG/OPALX/commits/a5c8592" --jq '.sha')

rm -rf "$TPL"; mkdir -p "$TPL"

# --- OPALX: mit origin fuer spaeteren Push -------------------------------
BASE_DIR="$TPL/OPALX"
mkdir -p "$BASE_DIR"
git -C "$BASE_DIR" init -q
git -C "$BASE_DIR" remote add origin "https://github.com/$ORG/OPALX.git"
git -C "$BASE_DIR" fetch -q origin "$FIX" --depth 2
CUTOFF=$(git -C "$BASE_DIR" log -1 --format=%cI FETCH_HEAD)
git -C "$BASE_DIR" checkout -q -b eval-$ISSUE FETCH_HEAD^
echo "Stichtag: $CUTOFF"
echo "OPALX -> $(git -C "$BASE_DIR" log -1 --format='%h %cI %s')"

# --- opalx-manual, regression-tests-x: reine Snapshots, kein origin ------
clone_snapshot() {   # $1 = Repo-Name, $2 = default branch
  local repo="$1" branch="$2"
  local dir="$TPL/$repo"

  # Commit-SHA vor dem Stichtag ueber die GitHub-API ermitteln (kein
  # lokales Fetch der vollen Historie noetig).
  local c
  c=$(gh api "repos/$ORG/$repo/commits?sha=$branch&until=$CUTOFF&per_page=1" --jq '.[0].sha')
  if [ -z "$c" ] || [ "$c" = "null" ]; then
    echo "FEHLER: kein Commit vor $CUTOFF in $repo auf $branch gefunden" >&2
    exit 1
  fi

  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "https://github.com/$ORG/$repo.git"
  git -C "$dir" fetch -q origin "$c" --depth 1
  git -C "$dir" checkout -q FETCH_HEAD -b eval-$ISSUE
  git -C "$dir" remote remove origin
  echo "$repo -> $(git -C "$dir" log -1 --format='%h %cI %s')"
}

clone_snapshot opalx-manual main
clone_snapshot regression-tests-x master

# --- OPALX einmal bauen, damit new-agent-run.bash den fertigen Build ------
# --- mitkopiert und Agenten nicht jedes Mal von Null bauen muessen -------
# Konfiguration/Optionen nach der "debug-testing"-Rezeptur der
# opalx-build-project-Skill: Debug + SERIAL + Unit- und Integrationstests
# ON, damit Agenten direkt `cmake --build build_serial` + `ctest` nutzen
# koennen, ohne neu zu konfigurieren.
NPROC=$(sysctl -n hw.ncpu 2>/dev/null || nproc)
echo "Baue OPALX im Template (kann 10+ Minuten dauern) ..."
cmake -S "$BASE_DIR" -B "$BASE_DIR/build_serial" \
    -DBUILD_TYPE=Debug \
    -DPLATFORMS=SERIAL \
    -DOPALX_ENABLE_UNIT_TESTS=ON \
    -DOPALX_ENABLE_TESTS=ON \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build "$BASE_DIR/build_serial" -j "$NPROC"
echo "Build fertig -> $BASE_DIR/build_serial"

# --- OPALX ein zweites Mal bauen, als "build_debug" -----------------------
# Agenten ignorieren manchmal den Hinweis in der opalx-build-project-Skill,
# einen nach einem Pfadwechsel kaputten build_serial per sed-Rewrite zu
# reparieren statt neu zu konfigurieren, und legen stattdessen einen neu
# benannten Ordner an (siehe session ses_f326: exakt dieser Aufruf). Damit
# das nicht wieder einen kompletten Rebuild von IPPL/Kokkos/heFFTe/HDF5
# ausloest, wird derselbe Ordnername hier vorab mitgebaut.
echo "Baue OPALX im Template zusaetzlich als build_debug ..."
cmake -S "$BASE_DIR" -B "$BASE_DIR/build_debug" \
    -DBUILD_TYPE=Debug \
    -DPLATFORMS=SERIAL \
    -DOPALX_ENABLE_UNIT_TESTS=ON \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build "$BASE_DIR/build_debug" -j "$NPROC"
echo "Build fertig -> $BASE_DIR/build_debug"
