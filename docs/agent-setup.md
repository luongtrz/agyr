# Orchestrator Agent Setup (Claude Code, Codex, Antigravity, Gemini CLI)

When an AI coding assistant delegates coding or investigation work to `agy` through `agy-task` and `agy-run`, install the matching skill: [`skills/agy`](../skills/agy) for Claude Code, Antigravity, and Gemini CLI, or [`skills/agy-codex`](../skills/agy-codex) for Codex.

## 1. Install the matching skill

Copy the skill for each assistant into that assistant's skill directory:

```bash
# Claude Code
mkdir -p ~/.claude/skills
cp -r ~/tools/agy-acct/skills/agy ~/.claude/skills/

# Antigravity / Gemini CLI
mkdir -p ~/.gemini/skills
cp -r ~/tools/agy-acct/skills/agy ~/.gemini/skills/

# Codex on this host (configured shared skill directory)
CODEX_SKILL="$HOME/.agents/skills/agy-codex"
if [ -e "$CODEX_SKILL" ]; then
  diff -qr ~/tools/agy-acct/skills/agy-codex "$CODEX_SKILL"
else
  mkdir -p "$HOME/.agents/skills"
  cp -r ~/tools/agy-acct/skills/agy-codex "$HOME/.agents/skills/"
fi
```

Other Codex setups may use `$CODEX_HOME/skills` or `~/.codex/skills`; install `agy-codex` under the skill root configured for that host. Invoke it explicitly as `$agy-codex`. If a skill already exists there, compare and merge changes so host-specific references are preserved.

## 2. Optional agent instructions (`CLAUDE.md` / `GEMINI.md` / `AGENTS.md`)

Add the snippet below to the relevant instructions file (for Codex, a project's `AGENTS.md`) if you want the main agent to act as planner and reviewer while delegating suitable implementation work to `agy`:

```markdown
## Role split: Orchestrator = planner & reviewer, agy = sub-agent coder

The main agent does NOT write or edit project code itself — **except** when it has already traced the exact line(s) to change during investigation (where delegating would cost more than the fix). Otherwise, delegate suitable implementation work to `agy`:
- Implement tasks go through `agy-task run`
- Read-only exploration tasks go through `agy-run`

Before any `agy` run, load the matching skill: `agy` for Claude Code, Antigravity, and Gemini CLI; `agy-codex` for Codex. Model selection (`gemini-3.8-flash-high`), flags, exit codes, quota/429 rotation, 503 fallback, and git worktree rules are in the skill. If `agy` is unavailable (login failure or the whole account pool is on cooldown), STOP and tell the user so they can re-login — do not silently fall back to coding it yourself.

Orchestrator responsibilities:
- **Plan, don't over-specify** — do only enough investigation to write a clear plan: goal, root cause or suspected area, relevant files, the pattern to mirror, and acceptance criteria. Do NOT pre-trace every line or write out the full code in the prompt — let `agy` locate and implement the details, then trace the code during review. Keep one bug or logical change per `agy` session; every prompt carries the `HARD RULES` block (`agy-task` appends it automatically).
- **Isolate** — implement tasks run only inside a dedicated git worktree created by `agy-task run` (never the main checkout); read-only exploration tasks may target the repository via `agy-run --add-dir`.
- **Launch individually** — launch each `agy-task run` or `agy-run` as its own separate background tool call (never bundle multiple tasks into one shell loop, wrapper script like `launch.sh`, or `for pid in ...; wait` command). Bundling hides individual task status from the user and blocks completion notifications until the slowest task finishes.
- **Review & verify** — treat `agy`'s output as untrusted: read the full diff, run relevant checks yourself, and verify `agy`'s conclusions against the code. If the result is wrong, send `agy` a corrected follow-up prompt (`agy-task run --name <task> --resume ...`) rather than fixing it by hand.
- **Integrate** — stage verified in-scope changes, commit, and clean up the worktree (`agy-task rm <task> -f`).
```
