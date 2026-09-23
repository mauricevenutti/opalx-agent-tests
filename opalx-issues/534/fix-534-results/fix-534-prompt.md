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

- Work only with the code in this directory and ../regression-tests-x, ../opalx-manual(already made available to you). No internet searches, no looking up existing issues.
- Never run `git pull`, `git fetch`, `git merge`, or `git rebase`, and never pass `--unshallow` to any git command. 


## Deliverables

At the end, report :
- Root cause (2–5 sentences) with the affected locations (file:line)
- The change you made in 2-5 sentences and the locations
- The new test and the result of the test run (pass/fail, with output)
- Any uncertainties or side effects you could not rule out

## Task

1. Find the root cause in the code. Name the affected locations (file and
   line number) and explain why the bug occurs.
2. Fix the bug with a minimal, targeted change. Do not modify code unrelated
   to the problem.
4. Write a regression test that fails without your fix and passes with it
   (you can find examples in ../regression-tests-x). Follow the conventions
   of existing tests in the repository.
5. Build the project and run the relevant tests. For build instructions, use the skill opalx-build-project. If building is not possible, state clearly what is missing instead of claiming a result. Then run the test.
6. Commit your changes, push the current branch to origin, and open a PR
   against the sandbox base branch:
   `git push origin HEAD`
   `gh pr create -R OPALX-project/OPALX --base fix-534-sandbox --head <your current branch name>`
   Mention @mohsensadr in the PR description. Write the deliverables into the pr.
   The PR is not optional and is the deliverable of this task: do not stop,
   and do not report completion, until `gh pr create` has succeeded and you
   have the PR URL. 
7. Verify the PR, don't just assume it: run
   `gh pr view -R OPALX-project/OPALX <branch> --json body,title -q .body`
   and confirm the returned body actually contains the root cause, the cahges and  the new
   test description including the test results as well as the uncertainties section, and an
   @mohsensadr mention. If any are missing, fix it with
   `gh pr edit -R OPALX-project/OPALX <branch> --body-file <file>` — do not
   report the task complete until this check passes. 



