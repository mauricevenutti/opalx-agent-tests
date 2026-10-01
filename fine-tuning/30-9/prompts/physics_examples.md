# Subagent for `physics`

## Prompt

`````text
You are writing training examples for a small fine-tuned "OPALX expert" model. OPALX is a particle accelerator simulation code (C++, built on IPPL and Kokkos). The expert model is meant to internalize *stable knowledge* about the codebase so a coding agent can ask it short questions instead of retrieving raw code chunks.

## Your task

Write **25 new examples** for the category **`physics`**: units, normalizations, coordinate frames, sign conventions — what the physical quantities in the code and in the input/output actually mean.

Write them to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/physics.json` as a JSON array of 25 objects. Do not modify any other file (in particular, do NOT edit `/Users/maurice/mt/fine-tuning/opalx_examples.json` or anything inside the OPALX checkout).

## Read these first

1. `/Users/maurice/mt/fine-tuning/opalx_examples.json` — the existing dataset (6 examples). Study the `physics` example closely: its tone, length, level of detail, and how `output` is hard-wrapped. Your examples must look like they belong in that file.
2. `/Users/maurice/mt/fine-tuning/finetuning.md` — the design note explaining what "stable knowledge" is versus "specific knowledge" that should be retrieved instead. (The examples inside that note were written from memory and are marked do-not-use; they only show the format.)

## Grounding rule (the most important one)

The source of truth is the checkout at `/Users/maurice/mt/opalx-repo/OPALX`, at commit `45e126f3a8e7023e31e878b20d1634dc813c71cb`. **Every claim in every `output` must be verified by reading the actual code in that checkout.** Do not write anything from memory of OPAL, OPAL-t, IPPL, or accelerator physics conventions in general: OPALX differs from classic OPAL in many places (units of attributes have changed, features are missing or new), and plausible-sounding memory is exactly the failure this dataset is trying to avoid. For a unit claim, find the conversion in the code (e.g. a `Units::` factor applied when the attribute is read, or the help string of the attribute plus where it is used). If you cannot find code supporting a claim, drop the claim or drop the example. Before finalizing each example, re-open the cited line ranges and confirm they really show what the output says.

Sibling checkouts `/Users/maurice/mt/opalx-repo/opal-manual` and `/Users/maurice/mt/opalx-repo/regression-tests-x` may help you understand things or find realistic snippets, but the manual can be out of date relative to the code; the code wins, and the cited sources must be files in the OPALX checkout.

## What makes a good example

- **Stable, not version-specific.** Target units, normalizations, frames and the reasons behind them — things that stay true across commits. Do not make the answer hinge on exact line numbers, exact signatures, or default values (those belong to retrieval). Line numbers go in `source`, never in `output`.
- **The instruction is what a coding agent would ask mid-task**: "Is this correct for OPALX?" with a code or input-deck snippet in `input`, or a direct question with empty `input`. Aim for roughly half with a non-empty `input` (a short, realistic snippet you write yourself containing a typical unit/frame mistake — include a few where the snippet is actually correct and the answer is "Yes"), and half with `input: ""`.
- **The output is short and direct**: answer first, then the relations/units, then (where useful) corrected code and a common pitfall. Roughly 80–250 words. Plain text, hard-wrapped at about 90 columns with `\n`, code and formulas shown inline without markdown fences or LaTeX, matching the existing examples. No markdown headers or bold.
- **25 distinct topics.** No two examples about the same fact. Do not repeat the existing example's topic (P is beta*gamma, kinetic energy = (gamma-1)*m, mass in eV) as the main point of an example.

Topic ideas to explore (hints only — find out what the code actually does): the `Units` namespace and which direction its conversion factors go; the `Physics` constants namespace and their units; units of BEAM attributes (energy, charge, current, frequency, number of particles) and how macro-particle charge is derived; units and meaning of element attributes as read in `src/Elements` (field strengths, RF voltage/frequency/phase, lengths, apertures); distribution attributes (sigmas, momenta, emission time, cutoffs) and their units; the lab frame vs. the reference/beam frame and how `CoordinateSystemTrafo` / quaternions are used to go between them; ELEMEDGE and element-local coordinates; path length s vs. z; time t and per-particle dt; how the space-charge fields are Lorentz-transformed; E and B units in field maps and in the particle container; what quantities the statistics/moments compute and in which units and normalization (rms sizes, normalized emittance, energy spread, mean energy); units in the output files (stat, H5); sign of charge and how it enters the pusher; the definition of RF phase/lag and autophasing reference; unit handling of per-particle M and Q views; momentum units in distributions (eV/c vs beta*gamma) and the conversion helpers in `Util`.

## Record format

Each array element is an object with exactly these keys:

```json
{
  "instruction": "...",
  "input": "...",
  "output": "...",
  "mcp_science_output": "",
  "category": "physics",
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

Validate that the file parses (`python3 -c "import json; d=json.load(open(PATH)); print(len(d))"`) and contains exactly 25 entries. Then reply with: the file path, a one-line topic list of the 25 examples, and any caveats (e.g. places where the code and the manual disagree, or where the code is internally inconsistent about a unit, so you left the topic out or noted it).
`````

## Response

`````text
The 25 `physics` examples are written and validated: the file parses, has exactly 25 entries with the required keys, and every cited line range exists in the OPALX checkout at `45e126f3a`.

File: `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/physics.json`

I touched nothing else except a generator script in the same scratchpad, `build_physics.py`, which rebuilds the JSON.

15 examples have a snippet in `input` (3 of those are correct and answered "Yes"), 10 have empty `input`. Outputs are roughly 180–265 words, plain text, wrapped at about 90 columns. All 25 are marked `grounding_check: pass`; I re-opened the cited ranges for each claim.

**Topics (by index)**
0. Direction of `Units::A2B` factors (always multiply)
1. `Physics::` masses are GeV, `PartData` wants eV; `Physics::EMASS` (kg) vs deck `EMASS` (GeV) — "Yes"
2. BEAM `ENERGY` is total energy in GeV; precedence GAMMA > ENERGY > PC
3. Macro Q/M views (C, GeV) vs reference q/m (e, eV) in the Boris kick
4. `BCHARGE` sign and how macro charge/mass are derived — "Yes"
5. `pc->R`/`P` live in the co-moving reference frame; `RefPartR`/`P` and `toLabTrafo` are lab
6. `CoordinateSystemTrafo`: `transformTo`/`From` for points, `rotateTo`/`From` for vectors, composition order
7. Element-local coordinates inside `apply()` (z = 0 at the entrance, not ELEMEDGE)
8. Placement: ELEMEDGE vs lab-frame pose X/Y/Z/THETA/PHI/PSI, radians, no mixing
9. Path length s vs z; what ELEMEDGE, ZSTART, ZSTOP refer to
10. Per-particle `dt` vs global `dT` (fractional dt for newly emitted particles)
11. RFCAVITY units: VOLT (MV/m scale), FREQ (MHz), LAG (rad)
12. Meaning of LAG: cos(ωt + φ), autophasing, APVETO, DC gun
13. 2D RF field-map file units (cm, MHz, MV/m, H in A/m) and normalisation
14. Quadrupole K1 → T/m via the global `P0` variable, not the BEAM's PC
15. SBEND (L = arc) vs RBEND (L = chord), ANGLE in rad, k0 and field
16. APERTURE arguments are full widths in metres
17. DISTRIBUTION sigmas: metres and β·γ
18. FROMFILE file layout and units
19. FLATTOP time profile: TPULSEFWHM, TRISE/TFALL (10–90 %), SIGMAT, CUTOFFLONG
20. EMISSIONSOURCE units, EKIN in eV → β·γ — "Yes"
21. rms size, normalised and geometric emittance definitions
22. Mean kinetic energy and dE are both MeV, dE is absolute
23. `.stat` column units and frames
24. Space-charge "solve frame" is a rotation plus shift, not a Lorentz boost

**Caveats**
- **Solenoid KS left out.** The help string says "normalised strength in m^-1" and `OpalSolenoid` computes `Bz = KS*P0/c`, but the applied field uses KS as a bare multiplier on the field map. The code is internally inconsistent, so I wrote no example.
- **RFCAVITY VOLT.** The help string says "MV", TRAVELINGWAVE says "MV/m". The code uses it as a multiplier on a map normalised to 1 MV/m peak, so example 11 describes it as peak field in MV/m.
- **GAUSS cutoffs.** For `TYPE=GAUSS` the CUTOFF* attributes are not read (that code is commented out; 3 sigma is fixed). Example 17 only says cutoffs are in units of sigma and makes no claim that they take effect.
- **Stale help strings.** `SIGMAT` says "(m)" but is used as a time in seconds; bend `ANGLE` says "dipole coefficient in m^-1" but is used as an angle in rad. The examples follow the code.
- **Stat `charge` column.** The header declares unit "1" but the value is in coulomb; example 23 says so.
- **`SpinTBMTPusher` comment.** It says charge is in C, but the tracker passes proton charges. I wrote no spin example.
- **Statements derived by reasoning from the code rather than stated in it:**
  - example 3: the e·1e9 ≈ 1.6e-10 ratio error;
  - example 4: a negative BCHARGE flips the space-charge force sign;
  - example 19: TRISE being a 10–90 % time, and the uniform disc's rms being half the semi-axis;
  - example 14: the conversion carries no charge state.
- **Overlap with existing examples.** Examples 3 and 10 touch the same code as the existing physics and framework_idiom examples (Q/M views, reference mass in eV) but make different points. Example 24 complements the existing numerics example and does not repeat the Lorentz formulas.
- **Version-specific details kept out of outputs.** No line numbers or default values appear in outputs. Example 14 says P0 has "a built-in default" without the value; example 12 mentions `OPTION AUTOPHASE = 0` only as the off switch.
`````
