---
name: ship
description: Take finished work to merged - commit, push, open the pull request (GitHub PR or GitLab merge request), arm auto-merge, watch the pipeline. Use when the user says ship, "push & PR", "push & MR", or asks for auto-merge or pipeline monitoring.
---

Each step ends on its own done-condition; stop and report when one cannot be met. The forge follows `git remote get-url origin`: github.com is GitHub (`gh`), anything else is GitLab (`glab`, where a pull request is a merge request).

1. **Where.** `git rev-parse --show-toplevel` must be a linked worktree (the repo's sibling `.wt/` directory, per its `AGENTS.md`) on a feature branch, never the main checkout or the default branch. Done: branch name printed and it is not the default branch.
2. **Commit** with explicit paths (never `-a`), message per the repo's `AGENTS.md` git workflow. Done: `git status --short` lists nothing you meant to ship.
3. **Push**: `git push -u origin HEAD`. Done: the remote branch exists.
4. **Open** the pull request per the repo's pull/merge request doc (e.g. `docs/agents/merge-request.md`: template, labels, evidence); with no such doc, `gh pr create --fill` / `glab mr create --fill`. Done: its number is known.
5. **Auto-merge**, only when the user asked for it. Done: auto-merge armed, or `merged` after the user chose an immediate merge.
   - GitHub: `gh pr merge <n> --auto --delete-branch` with the repo's merge method (`--squash`, `--merge` or `--rebase`). It needs "Allow auto-merge" in the repo settings; with no required checks GitHub merges at once, so ask the user first when `gh pr checks <n>` lists none.
   - GitLab: `glab mr merge --auto-merge` merges *immediately* while the pipeline is still `pending`; arm it through the API, which accepts a pending pipeline:
     ```sh
     glab api --method PUT "projects/:id/merge_requests/<iid>/merge" \
       -f merge_when_pipeline_succeeds=true -f should_remove_source_branch=true
     ```
     A pipeline `skipped` by path rules (a `scripts/`- or docs-only change) leaves nothing to wait on, and the API answers `405 Method Not Allowed` — read `head_pipeline.status` from `glab api "projects/:id/merge_requests/<iid>"` before arming. On `skipped`, auto-merge means an immediate merge: ask the user, then merge with the same call minus `merge_when_pipeline_succeeds`. A later push or rebase clears it; re-arm after every push.
6. **Watch**: run `bash ~/.claude/skills/ship/watch-pr.sh <number>` from the repo under Monitor. It prints `<state> pipeline=<status> merge=<status>` on every change and exits on `merged`, `closed`, a failed/canceled pipeline, or a conflict with the target branch. On a failure, read the red job (`gh pr checks <n>` / `gh run view <run-id> --log-failed`, or `glab ci view` / `glab ci trace <job-id>`) and report its cause; on a conflict, rebase onto the target branch as in the `pr-sweep` skill, push with `--force-with-lease`, re-arm auto-merge, and watch again. Done: merged, or the failing job's cause or the unresolved conflict reported.
7. **Clean up**, only when the user asked: `git worktree remove <path>` and delete the local branch. A directory locked by a running process (tgrep serve, a dev server) is reported, not force-deleted.
