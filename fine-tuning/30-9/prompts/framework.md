# Subagent for `framework_idiom`

## Prompt

`````text
You are writing training examples for a small fine-tuned "OPALX expert" model. OPALX is a particle accelerator simulation code (C++, built on IPPL and Kokkos). The expert model is meant to internalize *stable knowledge* about the codebase so a coding agent can ask it short questions instead of retrieving raw code chunks.

## Your task

Write **25 new examples** for the category **`framework_idiom`**: how OPALX uses the libraries it is built on (IPPL, Kokkos, MPI, HDF5/H5hut, GSL, googletest) — data declarations, loops, host vs. device memory, parallel decomposition, particle–grid coupling.

Write them to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/framework_idiom.json` as a JSON array of 25 objects. Do not modify any other file (in particular, do NOT edit `/Users/maurice/mt/fine-tuning/opalx_examples.json` or anything inside the OPALX checkout).

## Read these first

1. `/Users/maurice/mt/fine-tuning/opalx_examples.json` — the existing dataset (6 examples). Study the `framework_idiom` example closely: its tone, length, level of detail, and how `output` is hard-wrapped. Your examples must look like they belong in that file.
2. `/Users/maurice/mt/fine-tuning/finetuning.md` — the design note explaining what "stable knowledge" is versus "specific knowledge" that should be retrieved instead. (The examples inside that note were written from memory and are marked do-not-use; they only show the format.)

## Grounding rule (the most important one)

The source of truth is the checkout at `/Users/maurice/mt/opalx-repo/OPALX`, at commit `45e126f3a8e7023e31e878b20d1634dc813c71cb`. **Every claim about how OPALX uses a framework must be verified by reading the actual code in that checkout.** Do not write from memory of IPPL or Kokkos APIs in general or of classic OPAL: show the idiom as OPALX code actually writes it, with the type names, accessors and helper functions that exist in this checkout (confirm each identifier you use by grepping for it). Well-known Kokkos semantics (e.g. that lambdas capture views by value, that device views cannot be dereferenced on the host) may be used as explanation, but the pattern itself must be one you found in the code, and corrected snippets must use only identifiers that exist. IPPL itself is not vendored in this checkout (it is fetched at build time), so ground claims in how OPALX calls it, not in IPPL internals you cannot see. If you cannot find code supporting a claim, drop the claim or drop the example. Before finalizing each example, re-open the cited line ranges and confirm they really show what the output says.

Sibling checkouts `/Users/maurice/mt/opalx-repo/opal-manual` and `/Users/maurice/mt/opalx-repo/regression-tests-x` exist but are unlikely to help much here; the cited sources must be files in the OPALX checkout (`src/` and `unit_tests/` are both fine).

## What makes a good example

- **Stable, not version-specific.** Target idioms and the reasons for them — things that stay true across commits. Do not make the answer hinge on exact signatures, argument order, default values or line numbers (those belong to retrieval). Line numbers go in `source`, never in `output`.
- **The instruction is what a coding agent would ask mid-task**: "Is this the right way to ... in OPALX? If not, fix it." with a short code snippet in `input`, or "How do I ... in OPALX?" with empty `input`. Aim for roughly 60% with a non-empty `input` (a short, realistic snippet you write yourself containing a typical mistake — include a few that are actually correct, where the answer is "Yes" and explains why), and the rest with `input: ""`.
- **The output is short and direct**: answer first, then the reason, then corrected code and a pitfall. Roughly 80–250 words. Plain text, hard-wrapped at about 90 columns with `\n`, code shown inline without markdown fences, matching the existing examples. No markdown headers or bold.
- **25 distinct topics.** No two examples about the same fact. Do not repeat the existing example's topic (Q/M storage modes, `getQView()` length-1 vs per-particle view) as the main point of an example.

Topic ideas to explore (hints only — find out what the code actually does): taking attribute views (`getView()`) before a kernel and what may be captured in a `KOKKOS_LAMBDA` (not `this`, not host-only objects; copying members to locals first); `Kokkos::parallel_for` vs `parallel_reduce` over local particles and how results are then reduced across MPI ranks (`ippl::Comm`, the reduce calls actually used); host mirrors and `deep_copy` for reading/writing attributes on the host; when `Kokkos::fence()` is called; which math functions are used inside kernels (`Kokkos::sqrt` vs `std::sqrt`); `KOKKOS_INLINE_FUNCTION` / `KOKKOS_FUNCTION` on helpers used in kernels; how particles are created, destroyed and how `update()` / migration between ranks is triggered after positions change; local vs total particle counts; how the particle container, field container, mesh, field layout and solver are composed in `src/PartBunch`; how charge is scattered to the mesh and fields gathered back; how the mesh and domain decomposition are (re)built and load-balanced; vector/matrix types used inside kernels (`Vector_t`, `ippl::Vector`, dot/cross helpers); how element field evaluation is applied to all particles on device (functor/kernel patterns in `src/AbsBeamline` or `src/Algorithms`); random number generation on device (Kokkos random pools) in `src/Distribution`; timers (`IpplTimings`); `Inform` and rank-aware output; MPI-parallel HDF5/H5hut output and what must be copied to host first; how unit tests initialise IPPL/Kokkos (googletest fixtures in `unit_tests/`); precision/type aliases and execution/memory-space aliases in `OPALTypes.h`; guards for empty ranks (zero local particles); GSL error handling.

## Record format

Each array element is an object with exactly these keys:

```json
{
  "instruction": "...",
  "input": "...",
  "output": "...",
  "mcp_science_output": "",
  "category": "framework_idiom",
  "defer": false,
  "source": {"repo": "OPALX", "file": "src/...", "lines": "120-132", "commit": "45e126f3a"},
  "extra_sources": [{"repo": "OPALX", "file": "...", "lines": "25-58", "commit": "45e126f3a"}],
  "teacher": "claude-opus-5-5",
  "grounding_check": "pass"
}
```

- `mcp_science_output` must be the empty string; it is filled in later by a script.
- `source` is the single most important supporting location; `extra_sources` (may be an empty list) lists the others. `file` is relative to the OPALX repo root. `lines` is `"A-B"` or a single `"A"`, 1-indexed, and must be tight ranges that actually contain the supporting code (not whole files).
- Set `grounding_check` to `"pass"` only after you have re-read the cited lines against the output. Don't include an example you couldn't verify.

## Finishing

Validate that the file parses (`python3 -c "import json; d=json.load(open(PATH)); print(len(d))"`) and contains exactly 25 entries. Then reply with: the file path, a one-line topic list of the 25 examples, and any caveats (e.g. idioms the code is inconsistent about, so you left them out).
`````

## Response

`````text
The 25 `framework_idiom` examples are written to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/framework_idiom.json`. The file parses, has exactly 25 entries with the required keys in order, and `mcp_science_output` is empty throughout. No other file was modified: the OPALX checkout is clean and `opalx_examples.json` is untouched.

I read the cited code for each example at commit `45e126f3a` before writing it, and a script confirmed that every cited line range exists and that the OPALX/IPPL/Kokkos identifiers named in the outputs occur in `src/` or `unit_tests/`. Nothing was compiled.

**Shape of the set**
- 16 of 25 have a non-empty `input` (64%); 9 are "How do I ..." with empty input.
- Three snippets are correct and answered "Yes" (4, 20, 24); the rest contain a typical mistake.
- Outputs are 167–222 words, plain text, hard-wrapped at about 90 columns; a few code lines run to 95.

**Topics**
1. Host for-loop over an attribute view → `Kokkos::parallel_for` over `getLocalNum()`
2. No `this`/members inside `KOKKOS_LAMBDA`; copy to locals first
3. Local `parallel_reduce` count → global via `ippl::Comm->allreduce`; collective-call pitfall
4. Bunch centroid: `Vector_t` reduction, in-place allreduce, divide by `getTotalNum()` (Yes)
5. Reading attributes on the host via `create_mirror_view_and_copy`
6. Filling attributes from host data via `getHostMirror()` + `deep_copy`
7. `Kokkos::` math in kernels, `std::` on the host; `Util::getGamma` is host-only
8. `KOKKOS_INLINE_FUNCTION` helpers, no exceptions in device code, `Kokkos::abort`
9. `Vector_t`, `matrix3x3_t`, `prod_vector` inside kernels
10. `createParticles()` instead of the hidden `create()`; collective even for zero particles
11. Deletion in two stages: OR into `InvalidMask`, then `deleteInvalidParticles()`
12. Moment cache: `markMomentsDirty()` after changing R or P
13. Where migration (`update()`) happens and how ORB load balancing is triggered
14. `PartBunch` composition; `bunch->R(i)` is a throwing stub
15. Scatter via the `dt*Q` trick and gather back to the particles
16. Elements add to E/B with `+=`; per-step accumulation order
17. Looping over mesh fields: whole-field expressions and `ippl::parallel_for`
18. Field view indexing: rank-local with ghost offset
19. Mesh and FieldLayout are mutated in place, never replaced
20. Device random numbers with a Kokkos random pool and per-rank seeding (Yes)
21. `IpplTimings` timers
22. googletest fixture with `ippl::initialize`/`finalize` and host read-back
23. MPI-parallel H5hut output with device-to-host copies
24. Multi-quantity reduction with `SumArray<N>` and `Kokkos::Sum` (Yes)
25. Element-owned device data: View + host mirror, `DualView` for field maps

**Caveats**
- **Statements not visible in the checkout.** IPPL is not vendored, so a few explanatory sentences rest on how OPALX calls it or on general Kokkos/MPI semantics. The ones to know about:
  - Timers are looked up by name and accumulate (21), inferred from `getTimer("computeMoments")` being called on every invocation.
  - Each rank writes only its own slice into the shared H5 file (23).
  - The two ways of indexing a field cell are used interchangeably (17).
  - Random results depend on backend and rank count (20).
- **`update()` after the push (13).** The call in `ParallelTracker::pushParticles` is commented out with a TODO, and migration currently happens only in `CartesianDomainUpdater::updateLayoutsAndMigrate`. The example describes that state; it is the most likely of the 25 to go stale.
- **Inconsistent min/max code (12, 24).** `PartBunch::calcBeamParameters` uses `Kokkos::Max`/`Min` with 0.0 initial values, while `DistributionMoments::computeMinMaxPosition` uses `MaxArray`/`MinArray` with proper identities. I described only the latter and recommend `computeMinMaxR()`.
- **Debug-only citation (18).** Two of the supporting citations (`PoissonSolver.cpp` 111-118 and 134-136) are inside `#ifdef OPALX_FIELD_DEBUG`. The primary source, `DirichletPlaneWriter.h`, is regular code.
- **Left out.**
  - No standalone `Kokkos::fence()` example: usage is inconsistent (some element kernels have no fence, and one is commented "not needed"). It appears only as part of other patterns.
  - No standalone `Inform`/rank-aware output example: rank-0-only default printing is IPPL-internal, and the existing code_convention example covers `Inform`.
  - Not used, though grounded material exists: GSL error handler, type aliases in `OPALTypes.h`, bin iteration via hash and range policy, per-rank tables via `ippl::Comm->reduce`.
- **Mass units.** `getMView()` is documented in GeV, while the existing physics example says `PartData::getM()` is in eV. Both are true of different objects; none of the new examples depends on it.

The generator script is `gen_framework_idiom.py` in the same scratchpad directory. It is only the source for the JSON and can be deleted.
`````
