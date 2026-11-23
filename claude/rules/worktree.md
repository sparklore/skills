# Worktree starting point

1. New worktrees / new sessions must start from the branch currently checked out in **your** main working tree. First run: `git -C <main-checkout> branch --show-current`. When using `start_session`, put that into `source_branch` — do not rely on defaults.
2. Do not create a worktree from `main` or another default branch without the user’s consent — except when the user’s current branch *is* `main`.
3. At session start, verify this worktree’s HEAD is on (or branched from) the tip of the user’s current branch. If not: stop, report how many commits behind, create a new branch in this worktree from the user’s current branch, then proceed. Do not audit, code, or write docs from a stale base.
4. If the user’s current branch is already checked out in the main tree, do not check out the same branch name again in the worktree — branch from it under a new name.
5. If submodules are uninitialized in the worktree: read-only work may read the main checkout’s submodules; changing a submodule requires asking the user first.

Chinese reference (not installed): `zh/worktree.md`
