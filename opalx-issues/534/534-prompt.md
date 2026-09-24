You are working in the OPALX repository (particle accelerator simulation built on IPPL, C++/Kokkos) in the current directory.

## Bug report

When the field solver boundary conditions are set to open in the input
(BCFFTX = OPEN, BCFFTY = OPEN, BCFFTZ = OPEN), the field boundary conditions
are correctly treated as open. However, the particles are still treated as if
the domain were periodic: particles leaving the computational domain reappear
on the opposite side. Field and particles therefore use inconsistent boundary
conditions.

Expected: with open boundary conditions, particle coordinates must not be
wrapped periodically. With fully periodic boundary conditions, the existing
behavior must be preserved.

## Constraints

- Only use paths relative to your working directory. 
- There is no user, so never ask for permission, and if a tool call is rejected, check the path and try again
- Work only with the code in this directory and ../regression-tests-x, ../opalx-manual(already made available to you). No internet searches, no looking up existing issues.
- Never run `git pull`, `git fetch`, `git merge`, or `git rebase`, and never pass `--unshallow` to any git command. 
- Do not run `gh` or `git push` yourself; the skill `push-fix-to-github` does all communication with GitHub.


## Deliverables

At the end: 
1. After running the tests, use the skill `push-fix-to-github` to commit,
   push, and open the PR. Pass it these parameters:
   - issue number: 534
   - a PR title
   - the PR body, which must contain:
     - Root cause (2–5 sentences) with the affected locations (file:line)
     - The change you made in 2-5 sentences and the locations
     - The new test and the result of the test run (pass/fail, with output)
     - Any uncertainties or side effects you could not rule out
     - a mention of @mohsensadr
   Do not create, rename, or switch branches. The current branch is already
   linked to issue #534.
   The PR is not optional and is the deliverable of this task: do not stop,
   and do not report completion, until the skill's script has printed the
   PR URL. 
2. Before running the skill, check that your PR body really contains the root
   cause, the changes, the new test with its results, the uncertainties, and
   the @mohsensadr mention. If you notice afterwards that something is
   missing, write the corrected body and run the skill again: it updates the
   existing PR instead of opening a new one. 



## Task

1. Find the root cause in the code. Name the affected locations (file and
   line number) and explain why the bug occurs.
2. Fix the bug with a minimal, targeted change. Do not modify code unrelated
   to the problem.
4. Write a regression test that fails without your fix and passes with it
   (you can find examples in ../regression-tests-x). Follow the conventions
   of existing tests in the repository.
5. Build the project and run the relevant tests. For build instructions, use the skill opalx-build-project. If building is not possible, state clearly what is missing instead of claiming a result. Then run the test.
6. Run the skill `push-fix-to-github` (see Deliverables).




