---
name: pr-sweep
description: Sweep every open pull request (GitHub PR or GitLab merge request) and issue the user authored - rebase and resolve conflicts, wait out pipelines, report what still cannot merge. Use after a batch of work ships, or when asked to check, tidy or unblock all PRs, MRs or issues.
---

A **sweep** leaves every open pull request in one of three end states: **mergeable** (no conflict, pipeline green), **merged**, or **blocked** with a named cause the user must act on. The forge follows `git remote get-url origin`: github.com is GitHub (`gh`), anything else is GitLab (`glab`, where a pull request is a merge request).

1. **Inventory.** List the user's open pull requests and issues:
   - GitHub: `gh pr list --author @me --json number,isDraft,mergeable,mergeStateStatus,reviewDecision,autoMergeRequest,headRefName,baseRefName`, `gh issue list --author @me`; checks via `gh pr checks <n>`.
   - GitLab: `glab mr list --author=@me -F json`; issues through the API (`glab issue list -F json` returns nothing with `--author`): `glab api "projects/:id/issues?author_username=$(glab api user | jq -r .username)&state=opened&per_page=100"`; per merge request `glab api "projects/:id/merge_requests/<iid>"` for `draft`, `detailed_merge_status`, `head_pipeline.status`, `merge_when_pipeline_succeeds`, `blocking_discussions_resolved`.
   Done: one row per open pull request with its draft flag, merge status, pipeline status and auto-merge flag.
2. **Rebase** every row that conflicts or is behind (`dirty`, `behind`, `conflict`, `need_rebase`):
   - Work in the worktree that has the branch (`git worktree list`); with none, add one under the repo's `.wt/` per its `AGENTS.md`. The main checkout is shared with other sessions: never rebase, stash or reset there, and report a held `index.lock` rather than deleting it.
   - `git fetch origin && git rebase origin/<target>`. Resolve a conflict when both sides' intent can be kept (each side added different lines, or the target moved what the branch only touched in passing); keep a rebuilt or regenerated file as tool output (rerun the tool, never hand-edit it). Where both sides changed the same logic, `git rebase --abort` and mark the row **blocked: conflict needs a decision**, naming the files.
   - Rerun the checks the repo's `AGENTS.md` / verification doc names for the paths the resolution touched, then `git push --force-with-lease`, and re-arm auto-merge if step 1 showed it armed (the push clears it; arming per the `ship` skill).
   Done: each such row is rebased and pushed, or blocked with the files named.
3. **Wait.** For every row whose pipeline is pending or running, run `bash ~/.claude/skills/ship/watch-pr.sh <number>` from its repo under Monitor, in parallel. On a failed job, read its log (`gh run view <run-id> --log-failed`; `glab ci trace <job-id>`) and mark the row **blocked: <job> failed - <cause>**; a failure the rebase caused is fixed and pushed like step 2, and one that the target branch's own latest pipeline also shows is reported as inherited from the target. Done: no row is still pending or running.
4. **Classify the rest.** Draft, unresolved discussions, missing approvals or `reviewDecision` not approved: **blocked** with that cause; never undraft, resolve threads or approve on the user's behalf. Issues: an open issue with no open or merged pull request referencing it (`gh issue view <n> --json closedByPullRequestsReferences`, `glab api "projects/:id/issues/<iid>/related_merge_requests"`) is listed as **no PR yet**. Done: every row and issue has an end state.
5. **Report** one table: number, title, end state, what the sweep did (rebased, resolved files, pushed, re-armed), and for blocked rows the cause and the decision needed. Merging is the user's call or auto-merge's; the sweep never merges.

Run it on demand, or on an interval while the session stays open (`/loop 30m /pr-sweep`). Cloud schedules cannot reach a VPN-only forge.
