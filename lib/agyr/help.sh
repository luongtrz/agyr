usage() {
  cat <<'EOF'
agyr — rotate between multiple agy (Antigravity CLI) accounts

Usage: agyr <command> [args]        (agyr help <command> for the details of one command)
       agyr [agy arguments]         start agy with the selected account (same as 'agyr run'): 'agyr', 'agyr -c', 'agyr -p "..."'

Commands:
  list [-c] [--claude]     Measure every account's quota and show a table (* = selected account)
  save <name>              Save the current login as slot <name>
  use <name>               Switch to slot <name>
  swapui <n1> <n2>         Swap UI display order of two accounts in 'agyr list' (--reset to restore)
  rename <old> <new>       Rename a slot (its login, cooldown and quota data move with it)
  del <name>               Delete slot <name> permanently (removes its token and state)
  active                   Print the name of the account in use
  run [agy args]           Start agy with the selected account; plain 'agyr' / 'agyr -c' do the same
  rotate [time]            Interactive agy ran out of quota: cool this account down, switch to the next one
  next [-v]                Print the ready account whose weekly limit resets soonest (what agy-run switches to)
  cooldown <name> <time>   Mark an account as out of quota for a while
  clear <name>             Remove an account's cooldown
  lock <name>              Exclude an account from automatic rotation ('next'/'rotate')
  unlock <name>            Re-enable automatic rotation for an account
  locked [<name>]          Query locked slots (list all, or exit 0 if <name> is locked)
  test [name...]           Send "Hi" to every account (uses a little real quota) to start each 5-hour window
  forget [-f|--force]      Drop the login in use locally, so 'agyr' asks for a new login (replaces 'rm <token file>')
  backend                  Print where the login lives: file (Linux) or wincred (Windows Credential Manager)
  help [command]           This overview, or the details of one command

Typical use:
  agyr save work           After logging in with 'agyr': store that login as slot 'work' (once per account)
  agyr list                Which account still has quota?
  agyr use other           Switch account, then reopen agy with 'agyr'
  agyr rotate              agy ran out of quota: cool this account down and switch, then run 'agyr -c'

After every manual login with 'agyr', run 'agyr save <name>' so the slot does not drift from the real account.
EOF
  if [ "$BACKEND" = wincred ]; then
    cat <<'EOF'
WINDOWS: agy keeps its login in ONE Windows Credential Manager entry (gemini:antigravity). 'agyr use' overwrites that
entry with the slot's login (the previous login is backed up in accounts/.last-token.bak), so plain 'agy' and 'agyr'
behave the same afterwards. 'agyr list' measures the accounts one after another, then puts your login back.
EOF
  else
    cat <<'EOF'
IMPORTANT: agy 1.2.14+ keeps its login in the OS keyring and ignores the token file, so a plain 'agy' always uses the
account stored there, whatever 'agyr use' selected. Start agy with plain 'agyr' (same as 'agyr run'; 'agyr -c' continues the last conversation) to use
the selected account. 'agyr list' and agy-run already take care of this themselves.
EOF
  fi
  cat <<'EOF'

Exit codes:   0 ok | 1 error (or an account could not be measured) | 2 bad usage | 3 no account is ready
Environment:  AGYR_COLOR=auto|always|never (also NO_COLOR) | AGY_TZ (default UTC-7, i.e. UTC+7) | AGY_HOME | AGY_BIN |
              AGYR_BACKEND=file|wincred (default: by OS) | AGY_CRED_TARGET (wincred entry, default gemini:antigravity)
Files:        ~/.gemini/antigravity-cli/accounts/<name>.token (slots), accounts/state.json (active account, cooldowns,
              last measured quota), accounts/.last-token.bak (token that was replaced by the last 'use')
Also:         agy-run --help   (runs an agy task headless with automatic account rotation)
EOF
}

# agyr help [command] / agyr <command> --help
help_for() {
  case "${1:-}" in
    "") usage ;;
    save) cat <<'EOF'
Usage: agyr save <name>

Save the login currently in use (the token file ~/.gemini/antigravity-cli/antigravity-oauth-token) as slot <name> and
make <name> the active account. <name> may contain letters, digits, '-' and '_'.

Run it once per account after logging in with 'agyr', and again after every manual re-login.
EOF
      ;;
    use) cat <<'EOF'
Usage: agyr use <name>

Switch to slot <name>. The token currently in use is first written back to the slot it belongs to (matched by
refresh_token, so an access token that agy refreshed is not lost). A token that matches no slot is never written into
any slot; it stays in accounts/.last-token.bak.

A running agy keeps its old token: reopen agy after switching ('agy -c' continues the last conversation).
EOF
      ;;
    swapui) cat <<'EOF'
Usage: agyr swapui <name1> <name2>
       agyr swapui --reset

Swap the display positions of two accounts in 'agyr list' without affecting account rotation ('agyr next').

Use --reset (or 'reset') to clear custom UI ordering and restore default weekly reset order.
EOF
      ;;
    list|ls) cat <<'EOF'
Usage: agyr list [-c|--cached] [-w|--wide] [--claude]        (alias: ls)

Measure the real quota of every saved account with 'agy -p /quota' (no model call, 0 tokens) and print one table row per
account. The accounts are measured in parallel, each in a throwaway HOME holding a copy of its token, so the token in use
is never touched and running agy / agy-run processes are not disturbed.

Rows are ordered by when the weekly limit resets, soonest first (accounts without data, never measured or just failed, come
last); this is the order in which the weekly limits free up.

  *            marks the account the real token file belongs to
  !!           in the same marker column as '*': the account is locked ('agyr lock'): never picked by rotation, do not
               use it ('*!!' = the selected account is locked). Its status is shown as usual. The column widens
               for long names
  GEMINI 5H    % left of the 5-hour limit and when it resets
  GEMINI WEEK  % left of the weekly limit and when it resets
  ARGON 5H / ARGON WEEK  the same for the Gemini 4 Argon model; shown only when an account reports that limit
  CLAUDE 5H / CLAUDE WEEK  the Claude and GPT models limits; kept only for accounts that also have Gemini 4 Argon
  STATUS       ready | low (10% or less left) | weekly limit reached, <time> left (the 5-hour limit then shows 'off':
               it does not apply) | cooldown, <time> left | not measured | stale, past reset time | measure failed

An account at 0% automatically gets a cooldown until its reset time; an account with quota left has its cooldown cleared.
Colours: green above 40%, yellow 11-40%, red 10% or less. Only on a terminal (see NO_COLOR and AGYR_COLOR).

Options:
  -c, --cached   do not call agy; print the data saved by the last measurement
  -w, --wide     never hide columns (Argon always, Claude with --claude); adapts to terminal width
  --claude       show Claude and GPT quota columns (hidden by default)

Exit code: 0 ok, 1 some account could not be measured.
EOF
      ;;
    rename) cat <<'EOF'
Usage: agyr rename <old> <new>

Rename slot <old> to <new>. The saved login, the cooldown, the last measured quota and the "active" mark move with it.
The real token file is not touched and agy is not started. Names may contain letters, digits, '-' and '_'.

It refuses (exit 1, nothing changed) if <old> does not exist or <new> already exists. Do not rename a slot while an
agy-run is using it: agy-run remembers the name it started with.
EOF
      ;;
    del|rm) cat <<'EOF'
Usage: agyr del <name>        (alias: rm)

Permanently delete slot <name> from the pool.

Removes the slot file accounts/<name>.token and deletes <name> from active, cooldown, and quota state. If the login
currently in use belongs to <name>, it is also cleared (removing the live token file or Credential Manager entry), and
accounts/.last-token.bak is removed if it belonged to <name>.
EOF
      ;;
    active) cat <<'EOF'
Usage: agyr active

Print the name of the account in use: the slot the real token file belongs to (matched by refresh_token). If the token
file matches no slot, the name stored in state is printed instead. Prints nothing when there is no active account.
EOF
      ;;
    cooldown) cat <<'EOF'
Usage: agyr cooldown <name> <time>

Mark <name> as out of quota for <time>; 'next', 'rotate' and agy-run skip it until then.

<time> accepts 4h13m27s, 43m, 1d2h, plain seconds (90), or a whole sentence such as
"Individual quota reached. Resets in 4h13m27s." If it cannot be parsed, 5h is used.

'agyr list' sets and clears cooldowns by itself from the measured quota, so this is rarely needed by hand.
EOF
      ;;
    clear) cat <<'EOF'
Usage: agyr clear <name>

Remove the cooldown of <name>.
EOF
      ;;
    lock) cat <<'EOF'
Usage: agyr lock <name>

Exclude slot <name> from automatic account rotation ('agyr next', 'agyr rotate', and agy-run).
A locked account is never chosen automatically, but remains usable manually with 'agyr use <name>'.
EOF
      ;;
    unlock) cat <<'EOF'
Usage: agyr unlock <name>

Re-enable automatic account rotation for slot <name>.
EOF
      ;;
    locked) cat <<'EOF'
Usage: agyr locked [<name>]

Query locked slots without changing state or taking locks.

Without arguments: print locked slot names, one per line, sorted (exit 0).
With <name>: print nothing. Exit 0 if <name> is locked, 1 if not locked, 2 if the slot does not exist.
EOF
      ;;
    next) cat <<'EOF'
Usage: agyr next [-v|--why]

Print the account to switch to: among the ready accounts (those not on cooldown and not locked) the one whose weekly limit resets soonest, from
the last measurement; this is the order 'agyr list' shows. Accounts never measured come last, ties are broken by name. The
account in use is returned only when nothing else is ready. Locked accounts are skipped entirely. 'agy-run' and 'agyr rotate' use this to pick the next account,
so keep the numbers fresh with 'agyr list'.
If every account is on cooldown or locked: print nothing, report on stderr which one resets first (if any), and exit 3.
  -v, --why   also say on stderr which account was chosen and why
EOF
      ;;
    rotate) cat <<'EOF'
Usage: agyr rotate [<time>]

For when an interactive agy runs out of quota: put the active account on cooldown and switch to the next ready one.
The reset time is read from the most recent "Individual quota reached ... Resets in X" line in agy's log (only lines from
the last hour); pass <time> (for example 4h13m) to give it yourself. If neither is available, 5h is used.

Then exit agy and reopen it with 'agy -c' (a running agy keeps its old token).
Exit code 3, and no switch, if every account is on cooldown.
EOF
      ;;
    run) cat <<'EOF'
Usage: agyr run [agy arguments...]        (shorthand: agyr [agy arguments...])

Start agy (interactive, or any agy arguments you pass, e.g. 'agyr -c' or 'agyr -p "..."') using the login saved
in the token file, i.e. the account selected by 'agyr use' / 'agyr rotate' / 'agyr list'.

Why it exists: since agy 1.2.14 the login is kept in the OS keyring (GNOME keyring over D-Bus) and the token file is
ignored while the keyring is reachable, so a plain 'agy' keeps using whatever account is stored there. 'agyr run' starts
agy with the session bus made unreachable, so agy falls back to the token file. Shorthand: 'agyr' alone, or 'agyr' followed by a flag, is the same as 'agyr run ...'.

Note: '--help' / '-h' as the first argument shows agyr's help instead of being passed to agy, and a first argument that
does not start with '-' is read as an agyr command (use 'agyr run <word>' to pass such an argument to agy, e.g. 'agyr run models').
EOF
      ;;
    test) cat <<'EOF'
Usage: agyr test [-w|--wide] [<name>...]

Send "Hi" to every account (or only the named ones) and show what it did: this is ONE REAL REQUEST per account, so it uses a
little real quota (an agy run costs a baseline of roughly 20k tokens even for a one-word prompt).

Why: the idea is that an account's 5-hour limit window starts counting down at its first request, so one "Hi" per account
starts every window at the same moment. THAT IS AN ASSUMPTION, not something agy documents: check it. The RESETS column
shows the reset time after the call and, when the call moved it, "(was hh:mm)" with the time before; if nothing moved for an
account that had not been used, the Hi did not start a new window.

For each account it measures the quota (0 tokens), sends "Hi" with 'agy -p Hi' (model gemini-3.8-flash-low, the lowest effort, no tools,
empty temporary directory, nothing of yours is read), then measures again. Accounts that have Gemini 4 Argon in their quota
also receive "Hi" on gemini-4-argon-low and claude-sonnet-5-5-low. The table shows the reply (or the error), the
5-hour % before>after and the reset time. The accounts are handled like in 'agyr list' (in parallel on Linux, one after the
other on Windows), the login in use is never touched, and the saved quota data is updated.

Without names, accounts that are on cooldown (out of quota) are skipped. A named account is always tried.
A locked account ('agyr lock') is tested like any other, with or without names: only automatic rotation avoids it, and
the table marks it with '!!' before its name, as in 'agyr list'.

Options:
  -w, --wide     never hide columns (Argon and Claude always); adapts to terminal width

Exit code: 0 if every tried account answered, 1 if some did not.
Environment: AGYR_TEST_TIMEOUT (seconds an account may take, default 120)
EOF
      ;;
    forget) cat <<'EOF'
Usage: agyr forget [-f|--force]

Remove the login in use from THIS machine only (the token file on Linux, the Credential Manager entry on Windows), so the
next 'agyr' asks you to log in again. Nothing is revoked at Google, which is why this is used instead of agy's own logout.
Use it between logging in to different accounts: 'agyr' (log in), 'agyr save <name>', 'agyr forget', 'agyr' (next account)...
Log in with 'agyr', not a bare 'agy': on Linux a bare 'agy' (1.2.14+) logs in through the OS keyring and leaves the token file stale.

The login is backed up in accounts/.last-token.bak first. If it belongs to no slot it would be lost, so forget refuses
until you run 'agyr save <name>' (or pass -f / --force). It also clears the "active" mark, so 'agyr active' prints nothing and
agy-run refuses to start (exit 4) until a login exists again. Do not forget while an agy-run is running.
EOF
      ;;
    help) cat <<'EOF'
Usage: agyr help [<command>]

Show the overview, or the details of one command. 'agyr <command> --help' works too.
EOF
      ;;
    *) echo "agyr: no such command '$1'" >&2; usage >&2; return 2 ;;
  esac
}
