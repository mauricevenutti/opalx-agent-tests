# Subagent for `code_convention`

## Prompt

`````text
You are writing training examples for a small fine-tuned "OPALX expert" model. OPALX is a particle accelerator simulation code (C++, built on IPPL and Kokkos). The expert model is meant to internalize *stable knowledge* about the codebase so a coding agent can ask it short questions instead of retrieving raw code chunks.

## Your task

Write **25 new examples** for the category **`code_convention`**: naming, directory layout, class patterns, error handling and logging idioms — how OPALX code is conventionally written and organized.

Write them to `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/code_convention.json` as a JSON array of 25 objects. Do not modify any other file (in particular, do NOT edit `/Users/maurice/mt/fine-tuning/opalx_examples.json` or anything inside the OPALX checkout).

## Read these first

1. `/Users/maurice/mt/fine-tuning/opalx_examples.json` — the existing dataset (6 examples). Study the `code_convention` example closely: its tone, length, level of detail, and how `output` is hard-wrapped. Your examples must look like they belong in that file.
2. `/Users/maurice/mt/fine-tuning/finetuning.md` — the design note explaining what "stable knowledge" is versus "specific knowledge" that should be retrieved instead. (The examples inside that note were written from memory and are marked do-not-use; they only show the format.)

## Grounding rule (the most important one)

The source of truth is the checkout at `/Users/maurice/mt/opalx-repo/OPALX`, at commit `45e126f3a8e7023e31e878b20d1634dc813c71cb`. **Every claim in every `output` must be verified by reading the actual code in that checkout.** Do not write anything from memory of OPAL, OPAL-t, IPPL, or Kokkos in general: OPALX differs from classic OPAL in many places, and plausible-sounding memory is exactly the failure this dataset is trying to avoid. If you cannot find code supporting a claim, drop the claim or drop the example. Before finalizing each example, re-open the cited line ranges and confirm they really show what the output says.

Sibling checkouts `/Users/maurice/mt/opalx-repo/opal-manual` and `/Users/maurice/mt/opalx-repo/regression-tests-x` may help you understand things or find realistic snippets, but the cited sources must be files in the OPALX checkout.

## What makes a good example

- **Stable, not version-specific.** Target conventions, patterns, and rationale that stay true across commits. Do not make the answer hinge on exact line numbers, exact signatures, or default values (those belong to retrieval). Line numbers go in `source`, never in `output`.
- **The instruction is what a coding agent would ask mid-task**: "Does this follow the OPALX conventions? If not, fix it." with a code snippet in `input`, or a direct question with empty `input`. Aim for roughly half with a non-empty `input` (a short, realistic code snippet you write yourself that either follows or breaks a convention — include a few where the snippet is actually correct and the answer is "Yes"), and half with `input: ""`.
- **The output is short and direct**: answer first, then the reasoning, then (where useful) corrected code and a common pitfall. Roughly 80–250 words. Plain text, hard-wrapped at about 90 columns with `\n`, code shown inline without markdown fences, matching the existing examples. No markdown headers or bold.
- **25 distinct topics.** No two examples about the same fact. Do not repeat the existing example's topic (OpalException + Inform/gmsg logging in a getter) — though other aspects of error handling and logging are fine.

Topic ideas to explore (hints only — find out what the code actually does, and pick whatever is genuinely conventional there): member/static naming suffixes; attribute-index enums ending in SIZE and how itsAttr is filled; how a new element class is split across `AbsBeamline` / `BeamlineCore` / `Elements` and what each directory is for; how commands/definitions/actions are registered (OpalConfigure, OpalData); the `clone` / `update` / `execute` pattern on Object subclasses; the exception class hierarchy and which subclass to throw where; Inform levels and message prefixes; the `Units` and `Physics` namespaces instead of magic numbers; license/header-guard conventions; how unit tests are laid out under `unit_tests/` and registered in CMake; how source files are added to CMake; visitor pattern for beamline elements; type aliases in `OPALTypes.h`; clang-format/formatting rules if a config exists; `Util::` helpers; enum-to-string maps; timers.

## Record format

Each array element is an object with exactly these keys:

```json
{
  "instruction": "...",
  "input": "...",
  "output": "...",
  "mcp_science_output": "",
  "category": "code_convention",
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

Validate that the file parses (`python3 -c "import json; d=json.load(open(PATH)); print(len(d))"`) and contains exactly 25 entries. Then reply with: the file path, a one-line topic list of the 25 examples, and any caveats (e.g. conventions you looked for but found the code inconsistent on, so you left them out).
`````

## Response

`````text
The 25 `code_convention` examples are written and validated: the file parses, has exactly 25 entries with exactly the requested keys, and every cited range was re-read against its output at commit `45e126f3a`.

File: `/private/tmp/claude-501/-Users-maurice-mt-fine-tuning/66ff6415-cc81-499e-b402-0d59253899d7/scratchpad/code_convention.json`

Thirteen examples have an `input` snippet and twelve have `input: ""`. Three of the snippets are correct and answered "Yes" (5, 19, 21). Outputs are 146–228 words, hard-wrapped at no more than 91 columns, with no markdown. Nothing else was modified: `opalx_examples.json` and the OPALX checkout are untouched.

**Topics**
1. Member naming: `_m` for data members, `_s` for statics, legacy `its*` (input)
2. Element attribute enum runs from `= COMMON` to `SIZE`, plus `registerOwnership()` (input)
3. Three-class element split: `AbsBeamline/X`, `BeamlineCore/XRep`, `Elements/OpalX`
4. Registering exemplars in `OpalConfigure/Configure.cpp`
5. Exemplar constructor, clone constructor and `clone(name)` pattern (input, Yes)
6. Element `update()`: base call, `getElement()`, setters, `updateUnknown` (input)
7. Exception hierarchy and which subclass to throw where
8. `Action` versus `Definition` as base class
9. `Physics::` constants instead of literals or `M_PI`, with masses in GeV (input)
10. `Units::<from>2<to>` conversion factors (input)
11. Include guards and file header block
12. Unit test layout and `add_opalx_test` registration
13. Test fixture that initialises IPPL and `gmsg`, with no own `main()` (input)
14. Adding sources through `_SRCS` / `HDRS` in each directory's CMakeLists
15. Visitor pattern wiring for a new element
16. Type aliases `Vector_t`, `PartBunch_t`, `ParticleContainer_t` via `OPALTypes.h` (input)
17. `.clang-format` rules and the PR check
18. `enum class` plus `BiMap ..._s` plus `makePredefinedString` for string-valued attributes (input)
19. `IpplTimings` timers (input, Yes)
20. Adding a global OPTION: `Options.h`, `Options.cpp`, `Option.cpp`
21. Static `X::find(name)` through the `OpalData` singleton (input, Yes)
22. `if (itsAttr[X])` as the "is set" test, since `getReal` returns 0.0 when unset (input)
23. Include paths relative to `src/` (input)
24. Where a command's attribute-index enum lives
25. Testing commands and elements without the parser (`findAttribute`, `Testable<Class>`)

**Caveats**
- **Three citation deviations from the stated format.** Several citations point at `unit_tests/`, `.clang-format`, `README.md`, `.github/workflows/` and `CMakeLists.txt`, not `src/...`, though all are inside the OPALX repo. Examples 12, 13, 17 and 25 have their primary `source` there. `fill_mcp_answers.py` or a checker that assumes `src/` may need to know. Two ranges are wider than "tight" because the pattern is the whole block: `BeamlineVisitor.h` 64-132 and `Configure.cpp` 93-168.
- **Generalised from a majority pattern; minority exists.**
  - Example 1 (naming): exceptions exist, e.g. `static ... defaultAperture_m` and unsuffixed `shareFlag` / `elementID` in `ElementBase`, and `geometry` in `SolenoidRep`. The output covers this only as "legacy classes have unsuffixed or `its` members".
  - Example 11 (include guards): guard names vary widely (`OPAL_*_HH` 156, `OPALX_*_HH` 83, `OPALX_*_H` 36, unprefixed about 50). The only hard facts are "always `#ifndef`, never `#pragma once`" and "new files use `OPALX_`"; the output says the rest is mixed. This is the weakest example if you want to drop one.
  - Example 9 (constants): `M_PI` still occurs 3 times in `src/`, against 88 uses of `Physics::pi` / `two_pi`.
  - Example 23 (includes): about 215 bare-name includes exist against about 2100 directory-prefixed ones.
  - Example 3 (element split): `MultipoleT` and `VariableRFCavity` have no Rep class; the output states this.
- **Looked for, left out as inconsistent.**
  - Kokkos kernel label naming: 61 labels use `Class::method`, 45 do not.
  - `INFORM_ALL_NODES` per-rank logging: only two real uses outside `Main`.
  - `.hpp` versus `.tpp` for template code: mixed.
  - `opalx::` namespaces: only the SpaceCharge subsystem uses them.
  - Doxygen comment style: `///` and `@brief` are both common.
  - Inform level semantics: skipped because the existing example already covers them.
- **Reasoning rather than quoted code.** A few pitfall lines are inferred from the cited code: the OPTION clone-constructor reset in 20, the unregistered visitor ending in the empty `applyDefault` in 15, and the missing `_SRCS` entry showing up at link time in 14.
- **Invented names.** All `input` snippets use made-up classes (`Kicker`, `OpalKicker`, `KickerRep`, `KickerTable`, `Flush`) that do not exist in OPALX. That is intentional, but the expert model will see those names.

The builder and checker scripts are next to the JSON (`build_code_convention.py`, `check_code_convention.py`). `check_code_convention.py --dump N` prints the cited lines for example N.
`````
