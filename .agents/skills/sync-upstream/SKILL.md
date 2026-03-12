---
name: sync-upstream
description: "Sync a forked repository with its upstream source repository. Use when the user wants to fetch updates from the original repo, inspect divergence, merge upstream changes into the current branch, or push the synced branch back to their fork. Triggers on: sync upstream, update from upstream, merge from main repo, pull latest from source repo, keep fork updated."
user-invocable: true
---

# Sync Upstream

Keep a fork aligned with its source repository without guessing remotes or merge commands.

## The Job

1. Confirm the repository remotes and current branch.
2. Ensure an `upstream` remote exists and points to the source repository.
3. Fetch `upstream`.
4. Show how far the current branch is ahead/behind `upstream/<default-branch>`.
5. If the user wants updates applied, merge `upstream/<default-branch>` into the current branch.
6. If the user wants the fork updated, push the current branch to `origin`.

## Default Remote Convention For This Repo

For this Ralph fork:

- `origin` should be the user's fork
- `upstream` should be `git@github.com:snarktank/ralph.git`

If `upstream` is missing or wrong, fix it before fetching.

## Use The Helper Script

Run:

```bash
scripts/sync-upstream.sh
```

This prints:

- current branch
- `origin` and `upstream` URLs
- upstream default branch
- ahead/behind counts against `upstream/<default-branch>`

## Update Workflow

When the user asks to update from upstream:

1. Run `scripts/sync-upstream.sh`
2. If `upstream` is not configured to `git@github.com:snarktank/ralph.git`, add or correct it
3. Fetch `upstream`
4. Merge `upstream/<default-branch>` into the current branch with a normal merge commit only if needed
5. Resolve conflicts carefully if they appear
6. Run a quick sanity check if the repo has one
7. Push to `origin` if the user asked to update the fork too

## Communication

Report:

- which branch you synced
- whether the branch was already current or had upstream changes
- whether a merge commit was created
- whether the result was pushed to `origin`

## Safety Rules

- Do not use rebase unless the user explicitly asks for it
- Do not use destructive git commands
- If conflicts appear, stop and explain which files need resolution
- If there is no `upstream` remote, add it instead of asking the user to do it manually
