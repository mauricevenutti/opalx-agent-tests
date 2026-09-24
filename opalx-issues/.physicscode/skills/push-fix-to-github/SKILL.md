---
name: push-fix-to-github
description: |
  Commits the fix, pushes the current branch and opens the pull request for an OPALX
  issue. Use this skill once the fix is in place and the tests have been run: it is the
  only supported way to deliver the result. Parameters: the issue number, the PR title
  and the PR body.
---

# Push the fix to GitHub

This skill hands your work in. Do not run `git commit`, `git push` or `gh pr create`
yourself; the script below does all of it. Never run `git pull`, `git fetch`,
`git merge`, `git rebase` or anything with `--unshallow`.

## 1. Gather the parameters

- **Issue number**: given in the task prompt. The current branch is named
  `<issue>-fix-<run>`; check with `git rev-parse --abbrev-ref HEAD`.
- **PR title**: one short line describing the fix.
- **PR body**: Markdown with these sections, filled in from your actual work:
  - `## Root cause`: 2–5 sentences, with affected locations as `file:line`
  - `## Change`: 2–5 sentences on what you changed, with locations
  - `## Test`: the new regression test, and the result of running it
    (pass/fail, with the relevant output)
  - `## Uncertainties`: side effects or open questions you could not rule out
  - a mention of `@mohsensadr`

## 2. Write the body to a file

Write it to `pr-body.md` in the root of the OPALX checkout. The script keeps it out
of the commit and deletes it once the PR is created.

## 3. Run the script

From the root of the OPALX checkout:

```bash
bash <this skill's directory>/push-fix.bash <issue> "<title>" pr-body.md
```

The script stages all changes (except `physicscode.json` and the body file), commits, runs
`git push origin HEAD`, opens the PR against `fix-<issue>-sandbox` (or updates the
existing PR on rerun) and reads the PR back.

## 4. Check the result

The last line of output is `PR_URL: <url>`. The task is complete only once you have
that URL. If the script fails, read the error, fix the cause (e.g. empty body file,
wrong issue number) and run it again; rerunning is safe.
