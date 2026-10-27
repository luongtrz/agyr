# Parallel agy runs (max 20 at a time)

Read this when the user wants several independent tasks done at once.

**Limit:** up to **20** concurrent agy runs (user rule 2026-10-12, raised from 12 and earlier from 6). The reason is that agy and `agy-task` run no tests, so parallel agy runs do not load the machine; the load comes from YOUR verification afterwards, so run those one at a time (a worktree at a time), never several suites at once. Count live runs before launching more, both implement (`agy-task`) and read-only (`agy-run`): `pgrep -fc '^bash .*agy-(task run --name|run --prompt)'`. Other sessions' runs on the host count too.

**Never resume the same Claude session in a second terminal while the first is alive.** (2026-09-25: a `claude --resume` terminal committed/pushed a fix, removed a worktree and relaunched an audit while the other terminal drove the same task; the host also lagged with 3 agy runs + tsc/vitest/vite.) Before launching check `pgrep -af "agy -p"`; if `ps` shows another `claude --resume <this-session-id>`, stop and tell the user first.

**Rules**
- **Implement tasks: one git worktree per run** — `agy-task run --name <task> --base <same-sha> …` creates and prepares it (setup + copied generated files from the repo config), so give each parallel run its own `--name` and the same `--base`. Never let two runs write the same worktree — even disjoint files collide in concurrent vitest/tsc runs and make the diff impossible to attribute.
- Read-only review runs can share the main checkout (they must not write).
- Each parallel run burns its own quota; a 429 in one run doesn't stop the others — check every run's `result` event. All runs share one account pool (see `quota-auth.md`).
- If the tasks touch the same files heavily, run them sequentially in one worktree instead; parallelism pays only when the conflict surface is small.

**Integrate afterwards, one run at a time:** review each worktree's diff and run its tests yourself (one worktree at a time), commit it on its own branch, then cherry-pick the commits in a fixed order onto one integration branch (e.g. the first run's branch). Tasks touching the same files (validator + its test, same dialog) usually conflict at the ends of test files — resolve by keeping both sides, then re-run the full verify on the integrated branch before fast-forwarding the MR branch.

**Many queued tasks (seen 2026-10-05, 11 tasks):** run one small detached script (`setsid nohup queue.sh task1 task2 … &`, log to a file, tail it with Monitor) that starts `agy-task run --name <task> … &` for each task whenever fewer than MAX `agy-task run` processes are alive (each task's `--name` is its worktree; the summary lands in `.agy-sessions/<task>.summary.txt`). To change the cap or add a task, `kill` ONLY the queue's main PID (children keep running) and start a new queue for the not-yet-started tasks. Review each finished worktree as soon as its summary appears (read it + the diff, commit on its own branch) instead of waiting for the whole batch.
