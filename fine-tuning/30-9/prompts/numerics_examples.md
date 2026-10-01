# Subagent for `numerics`

## Prompt

`````text
You are writing training examples for a small fine-tuned "OPALX expert" model. OPALX is a particle accelerator simulation code (C++, built on IPPL and Kokkos). The expert model is meant to internalize *stable knowledge* about the codebase so a coding agent can ask it short questions instead of retrieving raw code chunks.

## Your task

Write **25 new examples** for the category **`numerics`**: why a numerical method was chosen, how it works at the level of its steps, its stability and accuracy limits, and known pitfalls.

Write them to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/numerics.json` as a JSON array of 25 objects. Do not modify any other file (in particular, do NOT edit `/Users/maurice/mt/fine-tuning/opalx_examples.json` or anything inside the OPALX checkout).

## Read these first

1. `/Users/maurice/mt/fine-tuning/opalx_examples.json` — the existing dataset (6 examples). Study the `numerics` example closely: its tone, length, level of detail, and how `output` is hard-wrapped. Your examples must look like they belong in that file.
2. `/Users/maurice/mt/fine-tuning/finetuning.md` — the design note explaining what "stable knowledge" is versus "specific knowledge" that should be retrieved instead. (The examples inside that note were written from memory and are marked do-not-use; they only show the format.)

## Grounding rule (the most important one)

The source of truth is the checkout at `/Users/maurice/mt/opalx-repo/OPALX`, at commit `45e126f3a8e7023e31e878b20d1634dc813c71cb`. **Every claim about what OPALX does must be verified by reading the actual code in that checkout.** Do not describe the algorithm from memory of classic OPAL or of textbook versions: read the implementation and describe the steps it actually performs, in the order it performs them. General numerical-analysis reasoning (e.g. why a scheme is second order, why an electrostatic solve needs a rest frame) is allowed as explanation, but only attached to behavior you have confirmed in the code, and any limit or pitfall you state must follow from what the code does (a missing check, an assumption visible in the implementation, a comment in the source). If you cannot find code supporting a claim, drop the claim or drop the example. Before finalizing each example, re-open the cited line ranges and confirm they really show what the output says.

Sibling checkouts `/Users/maurice/mt/opalx-repo/opal-manual` and `/Users/maurice/mt/opalx-repo/regression-tests-x` may help you understand things, but the manual may be out of date; the code wins, and the cited sources must be files in the OPALX checkout. Note that IPPL itself is not vendored in this checkout (it is fetched at build time), so ground claims in how OPALX calls and configures it, not in IPPL internals you cannot see.

## What makes a good example

- **Stable, not version-specific.** Target the method, its rationale and its limits — things that stay true across commits. Do not make the answer hinge on exact default values, line numbers or signatures (those belong to retrieval). Line numbers go in `source`, never in `output`.
- **The instruction is a why/how/when question a coding agent would ask mid-task**: "Why does X do Y instead of Z?", "Is it safe to ...?", "What limits the accuracy of ...?", "What goes wrong if ...?". Most should have `input: ""`; a handful (about 5–8) should have a short code or input-deck snippet in `input` with a question like "Is this numerically sound in OPALX?" (include one or two where the answer is "Yes").
- **The output is short and direct**: answer first, then the steps of the method, then limits and pitfalls. Roughly 100–280 words. Plain text, hard-wrapped at about 90 columns with `\n`, code and formulas shown inline without markdown fences or LaTeX, matching the existing examples. No markdown headers or bold.
- **25 distinct topics.** No two examples about the same fact. Do not repeat the existing example's topic (why CartesianPIC3D loops over energy bins / per-bin Lorentz transform) as the main point of an example.

Topic ideas to explore (hints only — find out what the code actually does): the Boris pusher in `src/Steppers` (half kick / rotation / half kick, what the temporary R rescaling is for, time centering of fields); the structure of one time step in `src/Algorithms/ParallelTracker.cpp` (order of push, field evaluation, space charge, kick, and why); how the space-charge mesh is sized and re-fitted to the bunch and what that implies for resolution; the available Poisson solver types/boundary conditions and what each is suited to; charge deposition / field gather interpolation order and its noise implications; how energy bins are built and adaptively merged in `src/PartBunch` (criteria, cost/accuracy trade-off); how often space charge is recomputed and what skipping it costs; how external field maps are interpolated (`src/Fields`) and their accuracy limits; how element fields are switched on/off along s and what happens at overlaps or edges; how ZSTOP / step-size segments decide the end of a segment (half-step tolerance); the orbit threader / autophasing procedure if present; how the reference particle is advanced versus the bunch; particle loss / termination handling and its effect on statistics; how moments and emittances are computed in `DistributionMoments` (centering, normalization, parallel reduction, precision issues); random number generation and seeding per rank in `src/Distribution` and reproducibility across rank counts; how distributions are sampled (inverse transform, cutoffs, emission over time); load balancing / repartitioning triggers; floating-point pitfalls visible in the code (single vs double precision options, catastrophic cancellation in gamma-1, tolerances); physics processes in `src/Processes` (e.g. decay or scattering sampling) and their step-size assumptions; filters in `src/Filters` and what they are used for.

## Record format

Each array element is an object with exactly these keys:

```json
{
  "instruction": "...",
  "input": "...",
  "output": "...",
  "mcp_science_output": "",
  "category": "numerics",
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

Validate that the file parses (`python3 -c "import json; d=json.load(open(PATH)); print(len(d))"`) and contains exactly 25 entries. Then reply with: the file path, a one-line topic list of the 25 examples, and any caveats (e.g. topics you looked for but that are not implemented in this checkout).
`````

## Response

`````text
The 25 `numerics` examples are written to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/numerics.json`. The file parses, has exactly 25 entries with the required keys, and nothing else was modified (the OPALX checkout is clean, `opalx_examples.json` untouched).

The generator script `build_numerics.py` sits next to it. It checks key order, word count (238–279 by whitespace split), line width (max 90 columns) and that every cited file and line range exists at the checkout. Seven examples carry an `input` snippet; two of those have a "Yes" answer.

**Topics (one line each):**
1. Boris kick: half E, exact rotation, half E, and why a rotation.
2. Unitless R rescaling around `push` and per-particle dt (snippet, Yes).
3. Order of operations in one ParallelTracker step and why.
4. RF phase evaluated at T + dT/2 (snippet, No).
5. Space-charge mesh re-fitted to the bunch on every solve and what that means for resolution.
6. Longitudinal mesh stretch during emission.
7. Poisson backends and boundary conditions (deck snippet with mixed boundaries, No).
8. CIC deposit and gather, the dt*Q weighting, noise.
9. Adaptive bin merging: dynamic programming over a cost function.
10. Cathode Dirichlet plane: image-charge deposit vs shifted Green's function.
11. Space charge is solved every step; when it is skipped (`SCSOLVEFREQ` snippet, No).
12. End of a step-size segment: half-step window around ZSTOP.
13. OrbitThreader: index map of elements along s, and the time-step vs element-length check.
14. Cavity autophasing: guess, hill climb, refinement.
15. Reference particle advance compared with the bunch.
16. Which element fields act on a particle; hard edges and overlaps.
17. Particle loss: mark then delete, and the effect on statistics.
18. Moments and emittance computation and where precision is lost.
19. RNG seeding per rank and reproducibility (`SEED=-1` snippet, No).
20. Particles born mid-step: fractional dt and the birth drift.
21. Decay sampling: exponential law with time dilation (snippet, No).
22. Thomas-BMT spin rotation and why its sub-stepping does not allow a larger DT.
23. RF field-map evaluation: 1D Fourier plus near-axis expansion vs 2D bilinear.
24. Kinetic energy from gamma - 1 and its cancellation limit (snippet, Yes).
25. `TIMEINTEGRATOR`/RK4/LF2 are not usable; the tracker always uses Boris.

**Caveats:**
- **Filters:** no example. `src/Filters` (Savitzky-Golay, FFT low-pass, stencil) is not referenced by any other code in this checkout.
- **Space-charge solve frequency:** there is no working one. `SCSOLVEFREQ` is parsed into `Options::scSolveFreq` but never read, so example 11 says the solve runs every step. This is more commit-specific than the rest.
- **Integrator choice:** same situation for example 25. `TIMEINTEGRATOR` is stored but unused, and the RK4/LF2 classes are unfinished (`\todo` in the kick and state copy).
- **Fractional charge deposit:** the FlatTop source comment says the fractional dt gives a fractional charge contribution. In the actual step order every dt is reset to the global step before the next deposition, so I did not claim it. Example 8 states what the code does.
- **IPPL internals:** not visible in the checkout. Claims about CIC, Hockney and the Green's function types rest only on how OPALX names and configures them. I gave no rationale for integrated vs standard Green's function.
- **General numerics reasoning:** a few statements are standard reasoning attached to confirmed code rather than read from it: the Boris phase error 2*atan(|t|), bilinear interpolation being second order, no self-force with matched CIC weighting, RK4 not being symplectic, and the digit estimates in example 24.
- **Hint topics without their own example:** load balancing (ORB repartitioning), the P3M solver (only a bullet in example 7), Gaussian and multivariate-Gaussian sampling, the binning-variable choice (only a bullet in example 9), traveling-wave cavities and FFT2D5. All are implemented and could fill further examples.
- **Deck syntax:** the `input` snippets in examples 7, 11 and 19 use attribute names taken from `FieldSolverCmd.cpp` and `Option.cpp` and the regression-test decks. They were not run through the parser.
`````
