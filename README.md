# agyr

Rotate between multiple Google accounts for `agy` (Antigravity CLI) when an account runs out of quota, and inspect each account's real quota.

- Uses only the official `agy` binary. No proxy, and never reads or prints token contents: it only swaps token files between slots.
- Using multiple accounts this way may conflict with Google's terms of service. Use in moderation.

## Quick install

Requires `bash`, `git`, `jq`. Tested with agy 1.5.1 on Linux.

```bash
git clone https://github.com/luongtrz/rotate-agy.git ~/tools/agy-acct
bash ~/tools/agy-acct/linux/install.sh       # Linux: symlinks into ~/.local/bin
bash ~/tools/agy-acct/windows/install.sh     # Windows (Git Bash): wrappers into ~/.local/bin
```

AI agents installing this repository should follow [AGENT.MCP.md](AGENT.MCP.md).

## Usage

```bash
agyr                  # start agy with the selected account
agyr list             # quota of all accounts (* marks the selected account)
agyr use <name>       # switch account
agyr save <name>      # save a manually logged-in account as a slot
agyr forget           # drop the local login before signing in to another account
agyr help             # command overview; agyr help <command> for details
```

Google sign-in is interactive: sign in with `agyr`, then run `agyr save <name>`.

## Documentation

- [docs/reference.md](docs/reference.md): how it works, full command reference, Windows backend, keyring bypass, environment variables, known limitations.
- [AGENT.MCP.md](AGENT.MCP.md): installation and verification guide for AI agents.
- [skill/agy](skill/agy): Claude Code / Antigravity skill for delegating tasks through `agy-task` and `agy-run`.

## Repository layout

- `bin/`: `agyr`, `agy-run`, `agy-task`
- `linux/`, `windows/`: platform-specific layers and install scripts
- `skill/agy/`, `templates/`, `test/`, `docs/`

## Tests

```bash
bash test/run.sh      # 795 checks using a fake agy and fake tokens; never touches real logins
```

## License

MIT, see [LICENSE](LICENSE).
