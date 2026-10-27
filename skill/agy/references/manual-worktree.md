# Manual implement workflow (fallback when `agy-task` is unavailable or too rigid)

Read this only if `agy-task` cannot be used. It is what `agy-task run` automates: create the worktree, prepare it, assemble the prompt, run agy-run, and verify.

1. **Worktree (Claude creates it, never agy: that needs write access to the main checkout):**
   ```bash
   cd "$REPO" && git status --short                  # must be clean
   git worktree add --no-track ".worktrees/agy-<task>" -b "agy/<task>" [<base-sha>]
   WT="$REPO/.worktrees/agy-<task>"
   ```
   `.worktrees/` and `.agy-sessions/` must be ignored (`.git/info/exclude` / `.gitignore`). Branching from `origin/<x>` needs `--no-track` (otherwise the branch tracks it); push with an explicit `branch:branch` refspec.
2. **Prepare it (a frontend monorepo):** in the worktree run `pnpm install --frozen-lockfile --prefer-offline`, `pnpm api:gen`, and copy `routeTree.gen.ts` of the three apps from the main checkout. Then check `ls packages/api-client/src/generated | wc -l` (~52) and run the verify command once on unmodified code before launching: `pnpm api:gen` behind `rtk err` has reported ok while generating nothing (2026-09-29: agy then broke the HARD RULES to "fix" it with `pnpm install --offline` and a self-referencing symlink). Put an ENVIRONMENT NOTE in the prompt: the env is prepared; on an env failure STOP, no pnpm install, no symlinks, no copying from outside.
3. **Prompt:** write the task part to `.agy-sessions/<task>.task.txt` (Repo/Task/Plan/Scope/Acceptance criteria/Verify commands, working directory = `$WT`), then append the HARD RULES without retyping them:
   ```bash
   { cat "$REPO/.agy-sessions/<task>.task.txt"; echo; \
     sed "s#<ABS_PATH>#$WT#g" ~/tools/agy-acct/templates/hard-rules.txt; } > "$REPO/.agy-sessions/<task>.txt"
   ```
4. **Run** (in the background, `git status` clean in `$WT` first), then wait for the completion notification:
   ```bash
   agy-run --prompt "$REPO/.agy-sessions/<task>.txt" --add-dir "$WT" --log "$REPO/.agy-sessions/<task>.jsonl"
   ```
5. **Verify yourself** in `$WT` (status, diff, build/lint/tests); then clean up: `rm -f .agy-sessions/<task>*.txt`, keep the log, `git worktree remove` + delete the branch.

`agy-task run` adds, beyond this: a scope check that also catches an agy commit (moved HEAD), baseline hashing, a compact summary and a usage log.
