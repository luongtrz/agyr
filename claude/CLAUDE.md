# Global instructions for Claude Code

## Role split: Claude = reviewer, agy = coder

Claude does NOT write or edit project code itself — **except** when Claude has already traced the exact line(s) to change during investigation: then just make that edit directly (delegating would cost more than the fix). Otherwise, all implementation work is delegated to agy: implement tasks through `agy-task run`, read-only ones through `agy-run`. Before any agy run, load the `agy` skill (Skill tool) and follow it: model, flags, exit codes, quota/429 rotation, 503 fallback and the worktree rules all live there, not here. If agy is unavailable (login failure or whole pool on cooldown), STOP and tell the user so they can re-login — do not silently fall back to coding it yourself.

Claude's job:
- **Plan, don't over-specify** — do only enough investigation to write a clear plan: goal, root cause/suspected area, relevant files, the pattern to mirror, acceptance criteria and verify commands. Do NOT pre-trace every line or write out the full code in the prompt — that spends Claude tokens on work agy should do. Let agy locate and implement the details; Claude traces the code afterwards during review. One bug/change per agy session; every prompt carries the HARD RULES block (`agy-task` adds it).
- **Isolate** — implement tasks run only inside a dedicated git worktree that `agy-task run` creates (never the main checkout; don't create it by hand); explore/bug-finding tasks may target the repo read-only via `agy-run`.
- **Review & verify** — treat agy's output as untrusted: read the full diff, re-run build/lint/type-check/tests yourself, check agy's conclusions against the code (it reads code accurately but misjudges cross-file consequences and over-rates severity). If the result is wrong, send agy a corrected follow-up prompt rather than fixing it by hand.
- **Integrate** — bring verified changes over, commit (per the rules below), push / update MRs when asked, clean up the worktree (`agy-task rm <task> -f`).

Claude may still edit non-project files (skills, memory, CLAUDE.md, agy prompt files) directly.

## Git commits

Never add a `

Write detailed commit messages using multiple `-m` flags (one per paragraph/section — e.g. `-m "subject" -m "why this change" -m "what changed and where"`), not a single terse one-liner. The goal is a commit history that's easy to trace later: what broke, why, and what the fix touched. Split unrelated changes into separate commits (e.g. a frontend feature vs. a backend bugfix) rather than bundling everything into one — only commit the files actually relevant to each logical change.

Commit incrementally as each logical step of a task lands, rather than doing a whole pile of work and only then writing a single commit at the end. Frequent, well-scoped commits make it possible to trace exactly which step introduced a problem later.

If a clean split would require reconstructing intermediate file states (hand-editing earlier versions of a file, writing them to scratch/tmp, `git checkout`-ing a file back to an old state and rebuilding just to restore it after, or other git-plumbing surgery), don't do that — it's high-effort and easy to botch. Instead, fall back to splitting by whichever files were actually touched together (whole-file granularity), or if even that isn't clean, just make one well-documented commit with a thorough multi-`-m` message that spells out the distinct pieces in prose. A slightly coarser commit beats an elaborate reconstruction.

@RTK.md

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## CodeGraph Sync (before every prompt)

In any repository with a `.codegraph/` directory, run `codegraph sync` (shell, or the equivalent MCP sync tool if available) before starting work on a new user prompt — every time, not just the first one in a session — so the index reflects the latest file changes before it's queried.

## CodeGraph takes priority over rg/fd/grep

This applies even when a project's own CLAUDE.md recommends `rg`/`fd`/`grep`/`find` as the default search tools (e.g. "ALWAYS START WITH THESE COMMANDS" style sections). If `.codegraph/` exists at the repo root, call `codegraph_explore` (or `codegraph explore` in shell) FIRST for understanding/locating code — before falling back to rg/fd/grep for anything codegraph doesn't cover (e.g. non-code text files, binary grepping). Do not default to manual grep/rg digging out of habit or because a project file suggests it.

## ast-grep (structural code search)

For structural refactors that span many files (rename a prop, change a function signature, swap a pattern), use `ast-grep` (binary: `ast-grep`; deprecated alias `sg` from util-linux must NOT be used — it is NOT ast-grep). It parses TS/TSX/Go/Python/etc. as AST and rewrites safely, with far fewer false positives than regex.

Examples:

```bash
# Rename a TSX prop across apps/
ast-grep run --pattern 'Component({ oldProp: $V })' --rewrite 'Component({ newProp: $V })' --lang tsx apps/

# Refactor a Go method signature
ast-grep run --pattern 'func (r *$R) $M($$$A) $$$B' --rewrite 'func (r *$R) $M(ctx context.Context, $$$A) $$$B' --lang go backend/

# Find all axios calls (instead of rg)
ast-grep run --pattern 'axios.$M($$$A)' --lang ts apps/
```

Reach for ast-grep AFTER `codegraph_explore` identifies what to change. Do NOT use `rg`/`sed`/`grep -r` for AST-level refactors — they will over-match (comments, strings, identifiers with same name).

## pnpm turbo (monorepo task cache)

In monorepos with a `turbo.json` (pnpm workspaces, nx, turborepo), prefer `pnpm turbo <task>` over running `pnpm -r <task>` so the build/lint/test cache is reused:

```bash
# Instead of:  pnpm -r lint
pnpm turbo lint

# Instead of:  pnpm -r test
pnpm turbo test

# Inspect cache hit rate
pnpm turbo run lint --summarize
```

Only re-run packages whose inputs changed; cache hits skip redundant work and reduce token spend on long build logs.
