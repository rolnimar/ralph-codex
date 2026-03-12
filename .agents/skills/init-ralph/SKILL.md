---
name: init-ralph
description: "Initialize a repository to use Ralph with Codex. Use when the user wants to bootstrap Ralph in a new project, copy the Codex runner files into another repository, add the standard Ralph gitignore entries, or set up the repository for the PRD -> prd.json -> ./ralph.sh workflow. Triggers on: initialize ralph, set up ralph in this repo, bootstrap ralph, install ralph here, add ralph to this repository."
user-invocable: true
---

# Init Ralph

Bootstrap a repository for Ralph's Codex workflow.

## The Job

1. Confirm the target repository path. Default to the current working directory.
2. Run the helper script:

```bash
scripts/init-ralph.sh [target-repo]
```

3. Confirm the files were created:
   - `scripts/ralph/ralph.sh`
   - `scripts/ralph/CODEX.md`
   - `scripts/ralph/prd.json.example`
   - `scripts/ralph/progress.txt`
4. Confirm `.gitignore` contains the Ralph working-file block.
5. Tell the user the next steps:
   - use `$prd` to create a PRD
   - use `$ralph` to convert it to `prd.json`
   - run `./scripts/ralph/ralph.sh`

## Notes

- This skill bootstraps the repository for Codex-first Ralph usage.
- It does not create the PRD or `prd.json`; that is still the job of the `prd` and `ralph` skills.
- Do not overwrite existing files unless the user explicitly asks for a refresh.
