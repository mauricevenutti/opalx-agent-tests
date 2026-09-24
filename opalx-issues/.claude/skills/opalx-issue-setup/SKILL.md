---
name: opalx-issue-setup
description: |
  Sets up a workspace for running a coding-agent study against a real,
  already-resolved OPALX-project/OPALX GitHub issue, with many (possibly
  parallel) agent runs per issue. It creates opalx-issues/<N>/, downloads
  the original issue text and the diff of the resolving PR into
  results/original/, and copies in the workflow scripts (fetch-issue,
  make-template, new-agent-run, run-agent, collect-run,
  session-to-markdown) plus a README explaining the workflow. Trigger this
  skill when the user wants to set up, scaffold, or prepare an OPALX issue
  for an agent study/evaluation, with phrases like "set up issue 534 for an
  agent study", "prepare workspace for OPALX issue N", "scaffold the
  agent-fix workflow for issue N", or "get issue N ready to test an agent
  on". Requires `gh` authenticated with access to OPALX-project/OPALX.
---

# OPALX issue setup (multiple runs per issue)

Given an OPALX-project/OPALX issue number `N`, this skill creates the
issue folder `opalx-issues/N/` (next to `opalx-issues/534/`) with:

- `opalx-N-fix/`: `fetch-issue.bash`, `make-template.bash`,
  `new-agent-run.bash`, `run-agent.bash`, `collect-run.bash`,
  `session-to-markdown.py`. They are copied unmodified from this skill's
  `scripts/` directory. Each script reads the issue number from its folder
  (`opalx-issues/N/`), so nothing needs templating.
- `opalx-N-fix/README.md`, made from `scripts/README.md.template` with
  `{{ISSUE}}` replaced by `N`.
- `results/original/`: `issue-N.md` (issue body and comments),
  `fix-N.diff`, `fix-N.commit`, `fix-N.base` and `fix-N.pr`, all written
  by `fetch-issue.bash`.

Every agent run of the issue follows the same lifecycle:
1. `new-agent-run.bash <run>` creates the working copy and the branch
   `N-fix-<run>`.
2. `run-agent.bash <run> [model]` runs the agent. The agent opens its PR
   into `fix-N-sandbox` through the physicscode skill `push-fix-to-github`.
3. `collect-run.bash <run>` moves the session, the diff and `meta.json`
   into `results/<run>/` and deletes the working copy.

Agents get no `gh` access and cannot push directly. This is enforced by
the bash permissions in the `physicscode.json` that `new-agent-run.bash`
writes. As a result, parallel runs can't read each other's PRs or the
original fix, and can't move the sandbox branch.

The physicscode skills that agents use (`opalx-build-project`,
`opalx-run-simulation`, `push-fix-to-github`) live in
`opalx-issues/.physicscode/skills/`, shared by all issues.
`new-agent-run.bash` refuses to run if `push-fix-to-github` is missing
there.

This skill deliberately does **not** write `opalx-issues/N/N-prompt.md`.
That is the task prompt handed to the agent, and writing it takes
judgment: it has to describe the bug without leaking the fix. Write it
with the user as a follow-up step:
- Base the bug description on `results/original/issue-N.md`.
- Consult `fix-N.diff` only to understand the root cause well enough for
  accurate verification criteria. Never quote or summarize its code
  change in the prompt.
- OPALX issues are often written by the developers and already name the
  root cause and even the fix (issue 534 does, with file:line). So don't
  paste the issue text either: describe only observed and expected
  behavior, as a user hitting the bug would.

`opalx-issues/534/534-prompt.md` is the structural model: bug report,
constraints, deliverables, task steps. Lessons from the 534 pilot runs
that every new prompt must cover:
- Agents often fixed the bug and then never committed, pushed or opened
  the PR. Delivery therefore goes through the skill `push-fix-to-github`.
  The prompt tells the agent to call it after the tests have run, with
  issue number `N`, a PR title, and a PR body with these sections:
  - root cause with file:line
  - the change and its locations
  - the new test and its result with output
  - uncertainties
  - an @mention of the reviewer
  
  Make the call a mandatory final task step: "do not report completion
  until the script printed the PR URL".
- Agents cannot run `gh`, so don't ask them to verify the PR with
  `gh pr view`. Tell them to check the body before calling the skill.
  Calling it again updates the existing PR.
- Forbid `git pull`/`fetch`/`merge`/`rebase` and `--unshallow` in the
  prompt as well: an unscoped pull unshallows origin and breaks the
  snapshot isolation. The permissions enforce this, but a clear rule
  saves the agent from denied attempts.
- The run branch is already linked to the issue via `gh issue develop`.
  Tell the agent not to create, rename or switch branches.

## Procedure

1. Confirm the issue number `N` with the user if not already given.
2. `mkdir -p opalx-issues/N/opalx-N-fix`, inside the workspace root
   (`~/mt`).
3. Copy all files from `scripts/` except `README.md.template` into
   `opalx-issues/N/opalx-N-fix/` verbatim, and keep them executable.
4. Generate `opalx-issues/N/opalx-N-fix/README.md` from
   `scripts/README.md.template` by replacing `{{ISSUE}}` with `N`.
5. Check that `opalx-issues/.physicscode/skills/push-fix-to-github/`
   exists. If it doesn't, tell the user.
6. Run `bash opalx-issues/N/opalx-N-fix/fetch-issue.bash`. This needs
   `gh` authenticated with access to `OPALX-project/OPALX`.
   - The script finds the resolving PR via GitHub's "closed by" link,
     falling back to timeline cross-references.
   - It warns if several merged PRs are linked, or if the PR was merged
     into a non-default branch. Relay any such warning to the user.
   - If it fails (for example, the issue was closed without a linked PR),
     ask the user for the PR number and run
     `bash fetch-issue.bash <pr-number>`.
   - If there is no PR at all (a direct commit), `make-template.bash
     <commit-sha>` accepts the fix commit and snapshots its parent.
7. Report back what was created. The next steps are:
   - write `N-prompt.md` together with the user;
   - `make-template.bash`;
   - then, per run: `new-agent-run.bash <run>`,
     `run-agent.bash <run> [model]`, `collect-run.bash <run>`.
   
   Run names must be unique per issue, e.g. `sonnet5-01`, `sonnet5-02`.

## Notes

- The scripts match the hand-maintained 534 scripts in
  `opalx-issues/534/opalx-534-fix/`. If those change, port the change
  here.
- The agent tool is `physicscode` (an opencode fork). It reads
  `physicscode.json` from the project dir (check with
  `physicscode debug config` inside a run's `OPALX/`, and
  `physicscode debug skill` for the skills it sees). Permission rules are
  evaluated with "last matching rule wins".
- Requires macOS/Linux with `gh`, `git`, `cmake`, `perl`, `python3`. The
  scripts are compatible with macOS's bash 3.2.
- Several steps touch GitHub, so the user runs them deliberately:
  - `make-template.bash` pushes `fix-N-sandbox`.
  - `new-agent-run.bash` creates each run branch on GitHub, linked to the
    real issue. A run name can't be reused until that remote branch is
    deleted.
  - The agent's PR stays open. Never merge it into the sandbox.
  - `run-agent.bash` publishes each transcript as a gist (needs the
    `gist` scope) and comments the link on the PR. Re-running it comments
    again.
- The template and the run copies are large build trees and are not kept
  under version control. `collect-run.bash` keeps only the session, the
  diff and `meta.json`, and deletes the run copy.
