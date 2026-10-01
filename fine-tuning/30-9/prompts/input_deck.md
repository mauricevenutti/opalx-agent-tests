# Subagent for `input_deck`

## Prompt

`````text
You are writing training examples for a small fine-tuned "OPALX expert" model. OPALX is a particle accelerator simulation code (C++, built on IPPL and Kokkos). The expert model is meant to internalize *stable knowledge* about the codebase so a coding agent can ask it short questions instead of retrieving raw code chunks.

## Your task

Write **25 new examples** for the category **`input_deck`**: the semantics of the OPALX input file — what commands, definitions and attributes mean, how they interact, and what the common mistakes are.

Write them to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/input_deck.json` as a JSON array of 25 objects. Do not modify any other file (in particular, do NOT edit `/Users/maurice/mt/fine-tuning/opalx_examples.json` or anything inside the OPALX checkout).

## Read these first

1. `/Users/maurice/mt/fine-tuning/opalx_examples.json` — the existing dataset (6 examples). Study the `input_deck` example closely: its tone, length, level of detail, and how `output` is hard-wrapped. Your examples must look like they belong in that file.
2. `/Users/maurice/mt/fine-tuning/finetuning.md` — the design note explaining what "stable knowledge" is versus "specific knowledge" that should be retrieved instead. (The examples inside that note were written from memory and are marked do-not-use; they only show the format.)

## Grounding rule (the most important one)

The source of truth is the checkout at `/Users/maurice/mt/opalx-repo/OPALX`, at commit `45e126f3a8e7023e31e878b20d1634dc813c71cb`. **Every claim in every `output` must be verified by reading the actual code in that checkout** — the attribute declarations and help strings, and the code that reads and uses them. Do not write anything from memory of classic OPAL / OPAL-t input decks: OPALX has dropped, renamed and added commands and attributes, and plausible-sounding memory is exactly the failure this dataset is trying to avoid. Confirm that every command and attribute you mention exists in this checkout and does what you say. If you cannot find code supporting a claim, drop the claim or drop the example. Before finalizing each example, re-open the cited line ranges and confirm they really show what the output says.

Sibling checkouts help here: `/Users/maurice/mt/opalx-repo/regression-tests-x` holds real working input decks (use them to write realistic `input` fragments and to see which commands are used in practice), and `/Users/maurice/mt/opalx-repo/opal-manual` is the manual. But the manual may be out of date relative to the code; the code wins, and the cited sources must be files in the OPALX checkout.

## What makes a good example

- **Stable, not version-specific.** Target the meaning of commands/attributes, how they combine, ordering and scoping rules, and silent-failure pitfalls — things that stay true across commits. Do not make the answer hinge on exact default values, exact line numbers or signatures (those belong to retrieval). Line numbers go in `source`, never in `output`.
- **The instruction is what a coding agent (or a user through it) would ask**: "What does this mean?", "Why does this deck not do what I expect?", "Is this valid?", with a short input-deck fragment in `input`, or a direct question with empty `input`. Aim for roughly two thirds with a non-empty `input` (a short, realistic deck fragment in OPALX syntax — include a few that are correct, where the answer confirms and explains), and the rest with `input: ""`.
- **The output is short and direct**: answer first, then the rules, then a common mistake. Roughly 80–250 words. Plain text, hard-wrapped at about 90 columns with `\n`, deck fragments shown inline without markdown fences, matching the existing examples. No markdown headers or bold.
- **25 distinct topics.** No two examples about the same fact. Do not repeat the existing example's topic (DT / MAXSTEPS / ZSTOP given as lists in TRACK).

Topic ideas to explore (hints only — find out what the code actually supports): the overall structure and required order of a deck (OPTION, definitions, elements, LINE, FIELDSOLVER, DISTRIBUTION, BEAM, TRACK ... RUN ... ENDTRACK); what RUN's attributes do and how RUN relates to TRACK; BEAM attributes and how particle count/charge/current relate; FIELDSOLVER attributes (type, mesh sizes, boundary conditions, parallelization flags) and what combinations are valid; DISTRIBUTION types and their attributes; OPTION flags that change behavior (e.g. QM_MODE, output frequencies like PSDUMPFREQ/STATDUMPFREQ, seeding, verbosity/INFO levels, VERSION); variables and expressions (REAL, CONST, `:=` deferred vs `=` immediate, arrays, string concatenation, booleans); how elements are placed (ELEMEDGE, LINE, ordering, overlapping elements); element attributes common to all elements (from OpalElement); energy-binning attributes; particle termination/apertures/boundary options; SELECT/VALUE/ECHO/CALL/SYSTEM/TITLE/STOP/QUIT and other basic actions in `src/BasicActions`; comments and statement termination rules in the parser; case sensitivity and abbreviation rules for keywords; what happens with unknown attributes or redefinitions; restart-related attributes and command-line options.

## Record format

Each array element is an object with exactly these keys:

```json
{
  "instruction": "...",
  "input": "...",
  "output": "...",
  "mcp_science_output": "",
  "category": "input_deck",
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

Validate that the file parses (`python3 -c "import json; d=json.load(open(PATH)); print(len(d))"`) and contains exactly 25 entries. Then reply with: the file path, a one-line topic list of the 25 examples, and any caveats (e.g. attributes that are declared but never read, or places where the manual and the code disagree).
`````

## Response

`````text
The 25 `input_deck` examples are written to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/input_deck.json`. The file parses, has exactly 25 entries with the required keys, and every cited line range was re-opened against the checkout at `45e126f3a`. Nothing was compiled or run: claims about behaviour (for example what `VALUE` prints, or which error a statement raises) come from reading the code.

17 examples have a deck fragment in `input` and 8 have `input: ""`. Four of the fragments are correct decks where the answer confirms and explains (8, 12, 15, 21). Outputs are 164–222 words, hard-wrapped at 90 columns or less. No other file was modified. The generator script `build_input_deck.py` sits next to the JSON in the scratchpad.

## Topics
1. Required statement order, and which references are resolved late
2. TRACK block: only RUN and ENDTRACK are known inside it
3. RUN attributes (METHOD, FIELDSOLVER) and where beam, line and distribution come from
4. The DISTRIBUTION → EMISSIONSOURCE → EMISSIONSOURCELIST → BEAM `SOURCES` chain; TRACK's `SOURCES` is ignored
5. BCHARGE, NALLOC and NPARTDIST: macro-charge versus number of particles created
6. BEAM energy: GAMMA > ENERGY > PC precedence and units
7. Species: PARTICLE versus MASS/CHARGE; BCURRENT/BFREQ rejected; PHOTON
8. Multi-beam tracking with `BEAMS = {...}`
9. FIELDSOLVER TYPE versus BCFFTX/Y/Z combinations
10. `TYPE = NONE` still needs NX/NY/NZ
11. BINNING and `FIELDSOLVER, BINS`; PARAMETER values that parse but fail at RUN
12. Emitted FLATTOP attributes (EMITTED, TRISE/TFALL, SIGMAT, TPULSEFWHM, CUTOFFLONG)
13. FROMFILE: forbids PC/ENERGY/GAMMA on the beam; file format
14. Element placement: ELEMEDGE or a lab-frame pose, never both or neither
15. Order inside LINE is irrelevant; overlapping elements add their fields
16. APERTURE string syntax (full widths) and particle deletion
17. When string values need quotes, and case of quoted names
18. Lexical rules: semicolons, comments, case, no abbreviations, fatal errors
19. `=` versus `:=`
20. Unknown attributes are hard errors (old FIELDSOLVER attribute names); HELP
21. OPTION statements accumulate; PSDUMPFREQ / STATDUMPFREQ / ENABLEHDF5
22. BOUNDPDESTROY N-sigma particle deletion
23. SEED and what `SEED = -1` really does
24. CHECKPOINTFREQ and `--restart`
25. Logical attribute values and the bare-flag shortcut

## Caveats

**Attributes that are declared but never read** (deliberately kept out of the examples):
- OPTION: SCSOLVEFREQ, REBINFREQ, DELPARTFREQ, REMOTEPARTDEL, CZERO, RNGTYPE, MINSTEPFORREBIN, MTSSUBSTEPS, PSDUMPEACHTURN, SPTDUMPFREQ and IDEALIZED are stored in `Options::` but nothing else in `src/` uses them.
- TRACK: TIMEINTEGRATOR, DTSCINIT, DTAU, T0, STEPSPERTURN and MAP_ORDER are stored in `Track::block` and not consumed. `TrackRun` hard-codes `"LF2"`.
- RUN: TURNS and TRACKBACK are not read. `BOUNDARYGEOMETRY` is read, but no `BoundaryGeometry` command is registered in `Configure.cpp`, so none can be defined.
- DISTRIBUTION: the CUTOFF* attributes are only read for FLATTOP-family types; for GAUSS and MULTIVARIATEGAUSS the cutoff is fixed at 3 and the attribute code is commented out.
- `OPTION, VERSION`: the mismatch check in `TrackRun` compares against `(major*100+minor)*100`, which is 900 for project version 0.9. The default `Options::version` of 10000 already exceeds that, so the option is inert in this build. The regression decks still set `VERSION=10900`.

**Code and help text or documentation disagree:**
- The SEED help text says -1 uses `time(0)`. That is true only for the input-language random generator. The particle samplers use the fixed seed 1234567 on every rank. Example 23 teaches the code's behaviour.
- BINNING `PARAMETER` accepts POSITIONZ and PZ, but `validateBinning` rejects everything except VELOCITYZ and GAMMAZ.
- `changes.cpp` still says the default aperture is a 1 m circle; the code default is an ellipse with 1e6 half-axes.
- The comment on NPARTDIST says a value of 0 or less falls back to "TrackRun/BEAM logic", but `TrackRun` passes 0 straight to the sampler. The examples only say NPARTDIST is the created count.
- I did not consult the opal-manual; everything is grounded in code plus the regression decks.

**Points to be aware of when reviewing:**
- Example 20 uses an "older OPAL" fragment (FSTYPE, MX/MY/MT, PARFFTT). What is grounded is that those names are not FIELDSOLVER attributes in this checkout; that they are the classic OPAL names is not verified against any source here.
- Example 15's input swaps the member order of a regression deck (`(D1, E1)` instead of `(E1, D1)`) to make the point. The field-summation claim is cited from the reference-particle path `OpalBeamline::getFieldAt`.
- Example 17 says `TYPE = "FFT2D5"` needs quotes. This follows from `parseStringValue` plus the absence of an FFT2D5 string constant; no deck in the regression tests uses FFT2D5 to confirm it.
- Examples 9, 10 and 20 all touch FIELDSOLVER, and 5 and 13 both mention NPARTDIST, but each covers a different fact.
- Several answers quote error-message fragments from the code. They are accurate at this commit but are the most version-sensitive part of the outputs.

Unrelated to this task: the claude.ai Google Drive connector needs authorization before its tools can be used. That has to be done in the claude.ai connector settings; it cannot be done from this non-interactive session.
`````
