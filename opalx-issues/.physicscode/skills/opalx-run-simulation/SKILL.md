---
name: opalx-run-simulation
description: |
  Runs OPALX simulations from the command line. Use this skill to execute an OPALX input
  file (e.g. "run opalx", "execute FodoCell-fromfile.in", "mpirun -np ... opalx"), or to
  run one of the regression tests in ../regression-tests-x/RegressionTests. Covers
  locating the built opalx binary in the current checkout, copying a regression test into
  a scratch folder, the mpirun command line and its flags, and quick post-run checks.
---

# Running OPALX

All paths are relative to the root of the current OPALX checkout (the directory you are
working in). The regression tests are in the sibling repository `../regression-tests-x`,
which is read-only: never run a simulation inside it.

## 1. Find the binary

The build folders sit in the checkout root, e.g. `build_serial` (Release, with tests) and
`build_debug` (Debug). The executable is `<build folder>/src/opalx`:

```bash
OPALX_BIN="$(pwd)/build_serial/src/opalx"
"$OPALX_BIN" --version
```

If the binary is missing or older than your source changes, rebuild first with the
`opalx-build-project` skill.

## 2. Prepare the input

- A local input file: run it from its own folder, since OPALX writes its output next to it.
- A regression test: copy its folder into a scratch directory inside the checkout
  (build folders `build_*` are gitignored, so use e.g. `build_serial/runs/`), then run
  from there:

```bash
mkdir -p build_serial/runs
cp -r ../regression-tests-x/RegressionTests/FodoCell-fromfile build_serial/runs/
cd build_serial/runs/FodoCell-fromfile
```

## 3. Run

```bash
mpirun -np 1 "$OPALX_BIN" FodoCell-fromfile.in --info 2 2>&1 | tee run.log
```

Optional flags: `--info <level>` (verbosity), `--restart <step>`, and
`--kokkos-map-device-id-by=mpi_rank` for multi-GPU runs. Start with `-np 1`.

## 4. Check the result

- Exit status and the tail of `run.log` (errors, "End of input file" / final step).
- Output files: `*.stat`, `*.h5`, `data/`, `timing.dat`.
- Quick checks, e.g. `grep -i "particles per macro particle" run.log`, or the final
  position/step in the `.stat` file.
- Regression tests ship reference results in the test folder; compare against them
  where relevant.
