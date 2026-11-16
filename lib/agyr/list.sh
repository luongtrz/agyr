cmd_list() {
  need_jq; init_state
  local cached=0 show_claude=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|--cached) cached=1 ;;
      -w|--wide) export AGYR_WIDE=1 ;;
      --claude) show_claude=1 ;;
      -cw|-wc) cached=1; export AGYR_WIDE=1 ;;
      "") ;;
      *) die "usage: agyr list [-c|--cached] [-w|--wide] [--claude]" 2 ;;
    esac
    shift
  done
  if [ "$show_claude" = 1 ]; then
    export AGYR_CLAUDE=1
  else
    unset AGYR_CLAUDE
  fi
  local -a names=()
  mapfile -t names < <(slots)
  if [ "${#names[@]}" -eq 0 ]; then
    echo "(no accounts yet; log in with 'agyr', then run 'agyr save <name>')"
    return 0
  fi
  local failed="" live=0
  if [ "$cached" -eq 0 ]; then
    if command -v "$AGY_BIN" >/dev/null; then
      if [ -t 2 ]; then printf 'Measuring quota of %d accounts…' "${#names[@]}" >&2; fi
      measure_all "${names[@]}"
      failed="$MEASURE_FAILED"
      if [ -t 2 ]; then printf '\r\033[K' >&2; fi
      live=1
    else
      echo "agyr: agy not found ($AGY_BIN), showing saved data" >&2
    fi
  fi
  print_table "$failed" "$live"
  [ -z "$failed" ]
}

# run [agy args...]: start agy with the login saved in the token file instead of the OS keyring, so 'agyr use' works.
cmd_run() {
  command -v "$AGY_BIN" >/dev/null || die "agy not found ($AGY_BIN)"
  local -a extra=()
  if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
    case " $* " in
      *" --dangerously-skip-permissions "*|*" --version "*|*" -v "*) ;;
      *) extra=(--dangerously-skip-permissions) ;;
    esac
  fi
  # wincred: the selected account already IS the login in Credential Manager, nothing to hide
  if [ "$BACKEND" = wincred ]; then exec "$AGY_BIN" "$@" "${extra[@]}"; fi
  exec env "${PLATFORM_ENV_KEYRING[@]}" "$AGY_BIN" "$@" "${extra[@]}"
}

# ---- agyr test: send "Hi" to every account -------------------------------------------------------------------------------
# One real request per account (~ the cost of the smallest possible agy run), so it uses a little quota. Purpose: the 5-hour
# window of an account starts counting down from its first request, so this starts every account's window now.

# hi_call <HOME for agy> <AGY_HOME for agy> [model]: run 'agy -p Hi' in an empty temp directory, no tools needed, detached from the
# terminal. Prints one line  STATUS<US>reply<US>error  (US = unit separator; reply/error on one line, cut at 200 chars)
