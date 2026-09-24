---
name: opalx-build-project
description: |
  Enables configuring and compiling the OPALX C++ project with CMake. Trigger this skill
  whenever the user wants to build, compile, configure, or rebuild OPALX — phrases like
  "build opalx", "cmake configure", "set up a debug build", "compile with unit tests",
  "rebuild after my change", "make a release build", "build for CUDA/GPU", or "the build
  is broken, what do I do". Also trigger if the user mentions a build folder
  (`build_serial`, `build_openmp`, `build_cuda`, ...), CMake options like `PLATFORMS`,
  `BUILD_TYPE`, or `ARCH`, or asks why `cmake --build` is failing. The skill knows the
  two-phase configure/build workflow, the important CMake options, the CMakeUserPresets
  shortcuts, and the common failure modes — use it instead of guessing CMake flags from
  scratch.

  1. Figure out which build the user wants (fresh first build, rebuild after a change,
     a different build type/platform, or a GPU/cluster build) and which build folder
     applies (`build_<something>`, never reusing one folder for a different
     compiler/MPI/backend). Before creating a new folder, check whether a build folder
     with matching options already exists (`grep -E "BUILD_TYPE|PLATFORMS|ARCH|OPALX_ENABLE"
     build_*/CMakeCache.txt`) and reuse it — including reconfiguring it in place to add a
     new test file or flip a test option — instead of standing up a fresh one. If
     reconfiguring an existing folder fails with a "CMakeCache.txt directory is different"
     error, see "Recovering a build folder copied from another path" below before
     defaulting to a from-scratch rebuild.
  2. Configure with `cmake -S . -B <build folder> -D<OPTION>=<VALUE> ...`, choosing
     sensible defaults (Debug + SERIAL + unit tests ON for local development) or the
     matching `CMakeUserPresets.json` preset if the user is on a known cluster (Alps
     GH200/MI300).
  3. Build with `cmake --build <build folder> -j <N>`, picking N based on available
     cores/memory (~2 GB per compiler job) and reminding the user this step is what to
     re-run after every source change — configure is only needed again when options or
     the file list change.
  4. Verify success by checking for the `opalx` executable in `<build folder>/src/opalx`
     (or wherever `OPALX_USE_STANDARD_FOLDERS` places it) and by running
     `--version` / `--git-revision` / `--help`.
  5. Diagnose common failures (missing compiler/MPI, out-of-memory kills, mismatched
     backend in an old build folder, a break inside `_deps/ippl-src`) and suggest the fix.
---

# Building OPALX

OPALX is a large C++ project (several hundred source files) built with CMake in two
phases. Understanding the two phases — and which one to re-run when — is the key to not
wasting time on unnecessary recompiles or stale build folders.

1. **Configure** (`cmake -S . -B <build folder> -D...`): CMake checks the system
   (compiler, MPI), applies the chosen options, downloads dependencies, and writes
   Makefiles into the build folder. Takes about a minute.
2. **Build** (`cmake --build <build folder> -j N`): actually compiles everything
   according to those Makefiles. The very first build also compiles all dependencies
   and is slow (tens of minutes); later builds only recompile what changed.

Re-run **configure** only when options change or files are added/removed. Re-run
**build** after every source edit or `git pull` — that alone picks up the changes.

## Core concepts

- **Build folder (out-of-source build).** Everything generated lives in a folder like
  `build_serial/`, separate from the source tree. Delete it to start fresh; keep several
  side by side for different option sets. `.gitignore` already excludes `build_*`.
  Never point two different compiler/MPI/backend combinations at the same build folder —
  create a new one instead, or you'll get confusing stale-cache errors.
- **Build type.** `Debug` (unoptimized, debugger-friendly, has extra checks) is for
  development. `Release` (optimized, hard to debug) is for production runs.
- **Dependencies.** OPALX fetches IPPL (which pulls in Kokkos and heFFTe), HDF5, H5hut,
  and GoogleTest into `<build folder>/_deps` and compiles them alongside OPALX. Only the
  compiler, MPI, and CMake need to be installed by hand.
- **IPPL tracks `master` by default.** Unless `IPPL_GIT_TAG` is pinned, every fresh
  configure fetches whatever IPPL's `master` currently is. If a build that used to work
  suddenly breaks with no OPALX changes, a new IPPL commit is a likely culprit — check
  `git log -1` inside `<build folder>/_deps/ippl-src` before assuming the problem is in
  OPALX itself.

## The important CMake options

Pass these as `-D<NAME>=<VALUE>` during configure.

| Option | Values | Meaning |
|---|---|---|
| `BUILD_TYPE` | `Debug`, `Release` | See above. |
| `PLATFORMS` | `SERIAL`, `OPENMP`, `CUDA`, `HIP`, `SYCL` | The Kokkos backend to build for. |
| `ARCH` | e.g. `AMPERE80`, `PASCAL61` | GPU architecture; required for GPU builds. `AMPERE80` = NVIDIA A100 (Gwendolen); `PASCAL61` = NVIDIA P100/GTX 1080 (Merlin). Must match the *compute node* GPU, not the login node. |
| `OPALX_ENABLE_UNIT_TESTS` | `ON`, `OFF` | Also build unit tests (`unit_tests/`). Keep `ON` for development. |
| `OPALX_ENABLE_TESTS` | `ON`, `OFF` | Also build the integration tests under `test/`. |
| `CMAKE_EXPORT_COMPILE_COMMANDS` | `ON`, `OFF` | Write `compile_commands.json` for editor tooling (clangd, etc.). |
| `IPPL_GIT_TAG` | `master` (default), a tag, a commit, or a version like `3.2.0` | Which IPPL version is fetched. |

The full list — including less commonly needed flags like `OPALX_USE_INSTALLED_HDF5`,
`OPALX_ENABLE_SANITIZER`, `OPALX_USE_STANDARD_FOLDERS` (moves binaries to `bin/`/`lib/`
in the build tree) — is in the repo's `README.md` under "Further Options". Skim it if the
user asks for something not covered above.

### CMakeUserPresets.json shortcuts

This repo ships `CMakeUserPresets.json` with ready-made option bundles. Prefer a preset
over hand-rolled flags when one fits:

- `default` — Release, SERIAL, `compile_commands.json` on, tests off. Good baseline.
- `debug-testing` / `release-testing` — `default` plus `OPALX_ENABLE_TESTS=ON` and
  `OPALX_ENABLE_UNIT_TESTS=ON`, in Debug or Release.
- `fetch` — like `default` but forces a fresh source checkout of Kokkos/heFFTe instead of
  using an installed version.
- `alps-gh200`, `alps-mi300` — CSCS Alps cluster defaults (CUDA/HIP + SLURM `srun` MPI
  wrapper). Use these on Alps rather than reconstructing the flags manually, and mention
  to the user that the CSCS pipeline expects a matching prepared software environment —
  point them to the team if something looks off.

Use a preset with `cmake --preset <name>` (configure) and
`cmake --build --preset <name>` or `cmake --build build_<name>` (build), depending on
whether the preset also defines a binary directory.

## Recipe: first build (Serial, Debug, with unit tests)

This mirrors the "CPU Serial" GitHub check and is the right default when someone just
wants a working `opalx` binary to develop against.

```bash
cd "$OPALX_SRC"   # repo root, e.g. the checkout you're already in
cmake -S . -B build_serial \
    -DBUILD_TYPE=Debug \
    -DPLATFORMS=SERIAL \
    -DOPALX_ENABLE_UNIT_TESTS=ON \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

Expect status lines like `Kokkos Backends: SERIAL`, `Heffte 2.4.0 building from source`,
`Building HDF5 from source`, a list of `Adding unit tests found in unit_tests/...`, and
finally `Build files have been written to: .../build_serial`.

```bash
cmake --build build_serial -j 4    # replace 4 with the number of cores to use
```

Each compiler process can need up to ~2 GB of RAM, so on an 8 GB laptop stay at `-j 3` or
`-j 4`. Expect progress lines like `[ 12%] Building CXX object ...`; warnings are normal,
errors stop the build. Completion looks like `[100%] Built target ...` with no error
above it. A first build can take on the order of 10+ minutes for the binary and longer
for unit tests, depending on machine speed.

When running the build step (`cmake --build ...`) as a tool call, set the command
timeout to **at least 10 minutes** (longer for a first build with unit tests, or on a
slower machine) — the default tool timeout is too short and will kill a build that's
still making progress, not actually stuck.

**Verify the result:**

```bash
ls -lh build_serial/src/opalx                 # the executable
ln -sf build_serial/compile_commands.json .   # optional, for editor tooling
du -sh build_serial                            # size sanity check (several GB is normal)

./build_serial/src/opalx --version        # IPPL version it was built with
./build_serial/src/opalx --git-revision   # full OPALX commit hash — compare to `git log -1 --format=%H`
./build_serial/src/opalx --help           # general options handled by IPPL (--info, --kokkos-help, ...)
```

If `OPALX_USE_STANDARD_FOLDERS=ON` was set (as in the `default` preset), the executable
lands under `build_serial/bin/` instead of `build_serial/src/` — check both if unsure.

## Rebuilding after a change

After editing source or pulling new commits, just re-run the build step:

```bash
cmake --build build_serial -j 4
```

Only changed files and their dependents recompile. Only re-run the `cmake -S . -B ...`
configure command if an option changed or files were added/removed. If a build folder
ever gets into a strange, hard-to-diagnose state, deleting it and configuring from
scratch is always a safe fix — it just costs the first-build time again.

If the user already has a build folder and you're not sure what it was configured with,
check before deciding whether to reconfigure:

```bash
grep -E "BUILD_TYPE|PLATFORMS|ARCH|OPALX_ENABLE" build_serial/CMakeCache.txt
```

If the cached options already match what's being asked for, skip straight to the build
step above.

## Other build variants

**Release build** (faster simulations, in its own folder so Debug stays available):

```bash
cmake -S . -B build_release -DBUILD_TYPE=Release -DPLATFORMS=SERIAL
cmake --build build_release -j 4
```

**OpenMP build** — same as Serial but `-DPLATFORMS=OPENMP` into `build_openmp`. On
macOS, OpenMP needs extra toolchain setup; recommend staying with Serial there unless the
user specifically needs OpenMP.

**GPU build on a cluster** (after loading the right modules on a login node):

```bash
cmake -S . -B build_cuda \
    -DBUILD_TYPE=Release -DPLATFORMS=CUDA -DARCH=AMPERE80
cmake --build build_cuda -j 8
```

Double-check `ARCH` matches the *compute* node GPU, not necessarily the login node's.
On Alps at CSCS, prefer the `alps-gh200` / `alps-mi300` presets above instead of manual
flags.

## Recovering a build folder copied from another path

If the repo checkout (and its `build_*` folders) was copied, rsynced, or otherwise
moved from a different absolute path — common when a build folder was produced in one
working-directory copy and the task now runs in another — CMake will refuse to reconfigure
it in place:

```
CMake Error: The current CMakeCache.txt directory <new>/build_serial/CMakeCache.txt is
different than the directory <old>/build_serial where CMakeCache.txt was created.
CMake Error: The source "<new>/CMakeLists.txt" does not match the source
"<old>/CMakeLists.txt" used to generate cache. Re-run cmake with a different source directory.
```

This happens because `CMakeCache.txt` and the generated Makefiles store the absolute
source/build paths as plain text — including inside every nested dependency cache under
`<build folder>/_deps/*/`. **Do not immediately delete the folder and rebuild from
scratch** — that re-downloads and recompiles IPPL, Kokkos, heFFTe, and HDF5, which is the
expensive part of a first build (tens of minutes). First try rewriting the stale absolute
paths throughout the folder to the current path, which usually lets CMake reuse the
already-built `_deps` tree:

```bash
old_path="<old>/build_serial"   # the path CMake reports in the error
new_path="$(pwd)/build_serial"  # the actual current path
grep -rlZ "$old_path" build_serial 2>/dev/null | xargs -0 sed -i '' "s|$old_path|$new_path|g"
cmake -S . -B build_serial   # reconfigure with no new options; should now succeed
```

Then verify with `cmake --build build_serial -j <N>` that only the expected files (e.g.
your new test) recompile, not the whole dependency tree. If the reconfigure still fails
after the path rewrite (e.g. compiler/toolchain also changed), fall back to deleting the
folder and configuring from scratch as usual — but treat that as the last resort, not the
first move, and don't paper over the failure by inventing a differently-named build folder
(`build_debug`, `build_test2`, ...) that just pays the same rebuild cost under a new name.

## Common build problems

- **CMake can't find a compiler or MPI.** Install/load the right modules, delete the
  build folder, and configure again from scratch.
- **The build gets killed, or the machine freezes.** Usually out of memory — reduce
  parallel jobs (`-j 2` or lower).
- **Switched compiler, MPI, or backend but reused an old build folder.** Don't — create
  a fresh build folder for the new combination instead of fighting stale cache state.
- **Error inside `_deps/ippl-src`.** Likely a recent upstream IPPL change (see the
  "IPPL tracks master" note above). Note the IPPL commit (`git log -1` in that folder)
  when asking the team about it.
</content>
