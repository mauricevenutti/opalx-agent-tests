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

## Task

1. Find the root cause in the code. Name the affected locations (file and
   line number) and explain why the bug occurs.
2. Fix the bug with a minimal, targeted change. Do not modify code unrelated
   to the problem.
3. Verify that all other solver and boundary-condition combinations still
   behave correctly.
4. Write a regression (you can find examples here: /Users/maurice/mt/tmp/regression-tests-x) - test that fails without your fix and passes with it.
   Follow the conventions of existing tests in the repository.
5. Build the project and run the relevant tests. For build instructions, use the skill opalx-build-project. If building is not possible, state clearly what is missing instead of claiming a result.

## Constraints

- Work only with the code in this directory (you may ask for the one with regression tests). No internet searches, no looking
  up existing issues or pull requests.
- Do not commit your changes; leave them in the working tree.

## Deliverables

At the end, report:
- Root cause (2–5 sentences) with the affected locations (file:line)
- The change you made (output of `git diff`)
- The new test and the result of the test run (pass/fail, with output)
- Any uncertainties or side effects you could not rule out