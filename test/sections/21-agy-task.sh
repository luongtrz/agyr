#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== agy-task"
setup # the old single-process run inherited this pool (AGY_HOME, FAKE_ARGS_LOG, tokens) from the previous section

# Help and usage
out="$("$TASK" --help 2>&1)"; rc=$?
eq "agy-task --help: exit 0" "0" "$rc"
has "agy-task --help: usage line" "agy-task run --name NAME --task FILE" "$out"
has "agy-task --help: mentions rm" "agy-task rm NAME [-f] [--repo DIR]" "$out"
has "agy-task --help: exit codes" "Exit codes:" "$out"
has "agy-task --help: mentions --resume" "--resume" "$out"

out="$("$TASK" 2>&1)"; rc=$?
eq "agy-task no args: exit 0" "0" "$rc"
has "agy-task no args: usage line" "agy-task run --name NAME --task FILE" "$out"

out="$("$TASK" -h 2>&1)"; rc=$?
eq "agy-task -h: exit 0" "0" "$rc"

out="$("$TASK" run --help 2>&1)"; rc=$?
eq "agy-task run --help: exit 0" "0" "$rc"

out="$("$TASK" rm --help 2>&1)"; rc=$?
eq "agy-task rm --help: exit 0" "0" "$rc"
has "agy-task rm --help: mentions rm" "agy-task rm NAME [-f] [--repo DIR]" "$out"

task_repo() {
  local d
  d="$(mktemp -d)"
  TMPS+=("$d")
  git -C "$d" -c user.name=t -c user.email=t@t init -b main >/dev/null
  cat <<'EOF' > "$d/.gitignore"
.agy-sessions/
.worktrees/
generated.txt
setup_marker.txt
EOF
  echo "hello world" > "$d/file.txt"
  echo "gen content" > "$d/generated.txt"
  git -C "$d" add .gitignore file.txt
  git -C "$d" -c user.name=t -c user.email=t@t commit -m "init" >/dev/null
  echo "$d"
}

# Argument validation
R="$(task_repo)"
echo "goal" > "$R/task.txt"
"$TASK" run --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "missing --name -> exit 2" "2" "$?"

"$TASK" run --name "BAD_NAME" --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "bad name characters (uppercase) -> exit 2" "2" "$?"

"$TASK" run --name "bad_name" --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "bad name characters (underscore) -> exit 2" "2" "$?"

"$TASK" run --name hp --repo "$R" >/dev/null 2>&1
eq "missing --task -> exit 2" "2" "$?"

"$TASK" run --name hp --task "$R/missing.txt" --repo "$R" >/dev/null 2>&1
eq "missing task file -> exit 2" "2" "$?"

"$TASK" run --name hp --task "$R/task.txt" --repo "$R" --unknown-flag >/dev/null 2>&1
eq "unknown flag -> exit 2" "2" "$?"

"$TASK" bogus >/dev/null 2>&1
eq "unknown command -> exit 2" "2" "$?"

# Missing config file
out="$("$TASK" run --name noconf --task "$R/task.txt" --repo "$R" 2>"$R/noconf.err")"
rc=$?
eq "missing config file: exit 0" "0" "$rc"
has "missing config file: warning printed to stderr" "warning: no config file found" "$(cat "$R/noconf.err")"
has "missing config file: summary OK" "RESULT=OK" "$out"

# Rejected --verify flag
"$TASK" run --name rejverify --task "$R/task.txt" --repo "$R" --verify x >/dev/null 2>&1
eq "rejected --verify flag -> exit 2" "2" "$?"

# Happy path
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_done > setup_marker.txt' )
COPY_FILES=( generated.txt )
EOF
SCRATCH="$(mktemp -d)"
TMPS+=("$SCRATCH")
echo "implement feature X" > "$SCRATCH/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EDIT="file.txt:modified by agy"
export FAKE_PROMPT_COPY="$SCRATCH/copied_prompt.txt"
unset FAKE_TASK_EXIT FAKE_TASK_RM

base_sha="$(git -C "$R" rev-parse --short HEAD)"
out="$("$TASK" run --name hp --task "$SCRATCH/task.txt" --repo "$R" --scope "file.txt" 2>"$SCRATCH/hp.err")"
rc=$?
eq "happy path: exit 0" "0" "$rc"
eq "happy path: worktree exists" "yes" "$([ -d "$R/.worktrees/agy-hp" ] && echo yes || echo no)"
eq "happy path: branch agy/hp exists" "yes" "$([ -n "$(git -C "$R" rev-parse --verify --quiet refs/heads/agy/hp)" ] && echo yes || echo no)"
branch_sha="$(git -C "$R" rev-parse --short refs/heads/agy/hp)"
eq "happy path: branch sits on base sha" "$base_sha" "$branch_sha"
upstream="$(git -C "$R" rev-parse --symbolic-full-name agy/hp@{upstream} 2>/dev/null || true)"
eq "happy path: branch has no upstream" "" "$upstream"
eq "happy path: setup marker exists" "setup_done" "$(cat "$R/.worktrees/agy-hp/setup_marker.txt" 2>/dev/null || echo missing)"
eq "happy path: COPY_FILES copied gitignored file" "gen content" "$(cat "$R/.worktrees/agy-hp/generated.txt" 2>/dev/null || echo missing)"

p_content="$(cat "$SCRATCH/copied_prompt.txt" 2>/dev/null || echo missing)"
has "happy path: prompt contains worktree path" "$R/.worktrees/agy-hp" "$p_content"
has "happy path: prompt contains task text" "implement feature X" "$p_content"
has "happy path: prompt contains scope" "file.txt" "$p_content"
has "happy path: prompt contains HARD RULES" "HARD RULES (violating any = task failure):" "$p_content"
hasnt "happy path: prompt has no literal <ABS_PATH>" "<ABS_PATH>" "$p_content"
hasnt "happy path: prompt no longer contains Verification commands" "Verification commands" "$p_content"
has "happy path: prompt contains reviewer runs verification instruction" "The reviewer runs all verification after you finish." "$p_content"

summary_content="$(cat "$R/.agy-sessions/hp.summary.txt" 2>/dev/null || echo missing)"
has "happy path: summary has RESULT=OK" "RESULT=OK" "$summary_content"
has "happy path: summary has changed file" "file.txt" "$summary_content"
eq "happy path: stdout equals summary file" "$summary_content" "$out"

# Sessions isolation and clean checkout
eq "prompt in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.prompt.txt" ] && echo yes || echo no)"
eq "jsonl in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.jsonl" ] && echo yes || echo no)"
eq "setup log in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.setup.log" ] && echo yes || echo no)"
eq "summary in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.summary.txt" ] && echo yes || echo no)"
eq "nothing agy-task wrote in worktree tracked tree" "" "$(git -C "$R/.worktrees/agy-hp" ls-files -o --exclude-standard)"
eq "main checkout git status porcelain is empty" "" "$(git -C "$R" status --porcelain)"

# Scope and forbidden files
R="$(task_repo)"
echo "task" > "$R/task.txt"
export FAKE_TASK_EDIT="other.txt:out_of_scope"
out="$("$TASK" run --name scfail --task "$R/task.txt" --repo "$R" --scope "file.txt" 2>"$R/scfail.err")"
rc=$?
eq "edit outside --scope -> exit 8" "8" "$rc"
has "edit outside scope: lists path" "other.txt" "$out"
has "edit outside scope: summary RESULT=SCOPE_VIOLATION" "RESULT=SCOPE_VIOLATION" "$out"

export FAKE_TASK_EDIT="pnpm-lock.yaml:lock"
out="$("$TASK" run --name forb --task "$R/task.txt" --repo "$R" 2>"$R/forb.err")"
rc=$?
eq "edit of pnpm-lock.yaml -> exit 8" "8" "$rc"
has "pnpm-lock.yaml violation listed" "pnpm-lock.yaml" "$out"

out="$("$TASK" run --name allow --task "$R/task.txt" --repo "$R" --allow-path "pnpm-lock.yaml" 2>"$R/allow.err")"
rc=$?
eq "edit of pnpm-lock.yaml with --allow-path -> exit 0" "0" "$rc"
has "allow-path: RESULT=OK" "RESULT=OK" "$out"

export FAKE_TASK_EDIT="file.txt:mod"
out="$("$TASK" run --name noscope --task "$R/task.txt" --repo "$R" 2>"$R/noscope.err")"
rc=$?
eq "no --scope -> exit 0" "0" "$rc"
has "no --scope: summary says not checked" "scope: not checked (no --scope)" "$out"

# Setup failure and missing COPY_FILES source
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_failure_message >&2; exit 1' )
COPY_FILES=()
EOF
echo "task" > "$R/task.txt"
export FAKE_TASK_EDIT="file.txt:should_not_run"
out="$("$TASK" run --name sfail --task "$R/task.txt" --repo "$R" 2>"$R/sfail.err")"
rc=$?
eq "setup failure -> exit 7" "7" "$rc"
has "setup failure: output tail shown on stderr" "setup_failure_message" "$(cat "$R/sfail.err")"
has "setup failure: summary RESULT=SETUP_FAILED" "RESULT=SETUP_FAILED" "$out"
eq "setup failure: stub agy-run never called" "no" "$([ -f "$R/.agy-sessions/sfail.jsonl" ] && echo yes || echo no)"

cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=()
COPY_FILES=( nonexistent.txt )
EOF
unset FAKE_TASK_EDIT
out="$("$TASK" run --name copymiss --task "$R/task.txt" --repo "$R" 2>"$R/copymiss.err")"
rc=$?
eq "missing COPY_FILES source -> exit 0" "0" "$rc"
has "missing COPY_FILES source: warning in stderr" "warning: copy source missing" "$(cat "$R/copymiss.err")"

# Stub agy-run exit codes (5, 4, 1)
R="$(task_repo)"
echo "task" > "$R/task.txt"
for code in 5 4 1; do
  export FAKE_TASK_EXIT="$code"
  out="$("$TASK" run --name "agyfail-$code" --task "$R/task.txt" --repo "$R" 2>"$R/agyfail-$code.err")"
  rc=$?
  eq "stub agy-run exit $code propagated" "$code" "$rc"
  has "stub agy-run exit $code: summary RESULT=AGY_FAILED" "RESULT=AGY_FAILED" "$out"
done
unset FAKE_TASK_EXIT

# Existing worktree and --reuse-worktree
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name reuse --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
out="$("$TASK" run --name reuse --task "$R/task.txt" --repo "$R" 2>&1)"; rc=$?
eq "existing worktree without --reuse-worktree -> exit 2" "2" "$rc"
has "existing worktree: clear message" "worktree already exists" "$out"

out="$("$TASK" run --name reuse --task "$R/task.txt" --repo "$R" --reuse-worktree --no-setup 2>"$R/reuse.err")"; rc=$?
eq "existing worktree with --reuse-worktree --no-setup -> exit 0" "0" "$rc"

git -C "$R" worktree remove "$R/.worktrees/agy-reuse" >/dev/null 2>&1
out="$("$TASK" run --name reuse --task "$R/task.txt" --repo "$R" 2>&1)"; rc=$?
eq "branch exists while worktree does not -> exit 2" "2" "$rc"
has "branch exists while worktree does not: clear message" "branch agy/reuse exists" "$out"

# agy-task --resume
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_done >> setup_marker.txt' )
COPY_FILES=()
EOF
SCRATCH="$(mktemp -d)"
TMPS+=("$SCRATCH")
echo "first task" > "$SCRATCH/task1.txt"
echo "correction task" > "$SCRATCH/task2.txt"

# Recording wrapper for agy-run
cat <<'EOF' > "$SCRATCH/record_run.sh"
#!/usr/bin/env bash
echo "$*" >> "$RECORD_LOG"
exec "$RECORD_TARGET" "$@"
EOF
chmod +x "$SCRATCH/record_run.sh"
export RECORD_LOG="$SCRATCH/agy_run_args.log"
export RECORD_TARGET="$FAKE_TASK_RUN"
export AGY_RUN="$SCRATCH/record_run.sh"

# (d) Normal first run: unchanged (no --conversation passed to agy-run)
export FAKE_TASK_EDIT="file.txt:first version"
out="$("$TASK" run --name res --task "$SCRATCH/task1.txt" --repo "$R" --scope "file.txt" 2>"$SCRATCH/res1.err")"
rc=$?
eq "normal run: exit 0" "0" "$rc"
eq "normal run: worktree created" "yes" "$([ -d "$R/.worktrees/agy-res" ] && echo yes || echo no)"
eq "normal run: setup executed" "setup_done" "$(cat "$R/.worktrees/agy-res/setup_marker.txt" 2>/dev/null || echo missing)"
run1_args="$(sed -n 1p "$RECORD_LOG")"
hasnt "normal run: agy-run called without --conversation" "--conversation" "$run1_args"
has "normal run: summary OK" "RESULT=OK" "$out"

# (b) Follow-up run with --resume:
# - reads conversation id of first run's init event in .agy-sessions/res.jsonl ("fake-conv-1")
# - passes --conversation fake-conv-1 to agy-run
# - implies --reuse-worktree and --no-setup
# - works on existing worktree
export FAKE_TASK_EDIT="file.txt:corrected version"
out="$("$TASK" run --name res --resume --task "$SCRATCH/task2.txt" --repo "$R" --scope "file.txt" 2>"$SCRATCH/res2.err")"
rc=$?
eq "resume run: exit 0" "0" "$rc"
run2_args="$(sed -n 2p "$RECORD_LOG")"
has "resume run: passes conversation id to agy-run" "--conversation fake-conv-1" "$run2_args"
eq "resume run: works on existing worktree" "corrected version" "$(cat "$R/.worktrees/agy-res/file.txt")"
eq "resume run: setup skipped (implied --no-setup)" "1" "$(wc -l < "$R/.worktrees/agy-res/setup_marker.txt" | tr -d ' ')"
res_prompt="$(cat "$R/.agy-sessions/res.prompt.txt")"
has "resume run: prompt contains new task" "correction task" "$res_prompt"
has "resume run: prompt contains HARD RULES" "HARD RULES" "$res_prompt"
has "resume run: prompt contains closing test reminder" "Do NOT run any test" "$res_prompt"

# (c) --resume with no previous log exits 2
out="$("$TASK" run --name nolog --resume --task "$SCRATCH/task1.txt" --repo "$R" 2>&1)"
rc=$?
eq "--resume with no previous log exits 2" "2" "$rc"
has "--resume with no previous log: clear message" "cannot resume: session log not found" "$out"

# --resume with log lacking conversation_id exits 2
echo '{"event":"other"}' > "$R/.agy-sessions/badlog.jsonl"
out="$("$TASK" run --name badlog --resume --task "$SCRATCH/task1.txt" --repo "$R" 2>&1)"
rc=$?
eq "--resume with no conversation id in log exits 2" "2" "$rc"
has "--resume with no conversation id: clear message" "cannot resume: no conversation id found" "$out"

unset AGY_RUN RECORD_LOG RECORD_TARGET FAKE_TASK_EDIT

# Invoked from inside a linked worktree
R="$(task_repo)"
echo "task" > "$R/task.txt"
mkdir -p "$R/.worktrees"
git -C "$R" worktree add "$R/.worktrees/wt-sub" -b wt-sub >/dev/null 2>&1
echo "sub branch work" >> "$R/.worktrees/wt-sub/file.txt"
git -C "$R/.worktrees/wt-sub" commit -am "wt-sub commit" >/dev/null
sub_sha="$(git -C "$R/.worktrees/wt-sub" rev-parse --short HEAD)"
main_sha="$(git -C "$R" rev-parse --short HEAD)"
(
  cd "$R/.worktrees/wt-sub"
  "$TASK" run --name linked-wt --task "$R/task.txt" >/dev/null 2>"$R/linked-wt.err"
)
rc=$?
eq "invoked from inside linked worktree -> exit 0" "0" "$rc"
eq "invoked from inside linked worktree: worktree in main repo" "yes" "$([ -d "$R/.worktrees/agy-linked-wt" ] && echo yes || echo no)"
eq "invoked from inside linked worktree: sessions in main repo" "yes" "$([ -d "$R/.agy-sessions" ] && echo yes || echo no)"
eq "invoked from inside linked worktree: base defaults to linked wt HEAD, not main" "$sub_sha" "$(git -C "$R/.worktrees/agy-linked-wt" rev-parse --short HEAD)"

# Baseline: setup modification not blamed on agy
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_change >> file.txt' )
COPY_FILES=()
EOF
echo "task" > "$R/task.txt"
export FAKE_TASK_EDIT="other.txt:created_by_agy"
out="$("$TASK" run --name base-check --task "$R/task.txt" --repo "$R" --scope "other.txt" 2>"$R/base-check.err")"
rc=$?
eq "baseline: setup modification not blamed on agy -> exit 0" "0" "$rc"
has "baseline: summary RESULT=OK" "RESULT=OK" "$out"
hasnt "baseline: file.txt not in violations" "violation: file.txt" "$out"

# Regression tests for defects

# Defect 2: agy commit bypasses scope check
# 2a: agy commits an in-scope edit
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EDIT="file.txt:commit_edit"
export FAKE_TASK_COMMIT=1
out="$("$TASK" run --name cminscope --task "$R/task.txt" --repo "$R" --scope "file.txt" 2>"$R/cminscope.err")"
rc=$?
eq "committed in-scope edit -> exit 8" "8" "$rc"
has "committed in-scope edit: HEAD-moved violation" "violation: agy moved HEAD (committed):" "$out"
has "committed in-scope edit: file listed under changed files" "file.txt" "$out"
has "committed in-scope edit: RESULT=SCOPE_VIOLATION" "RESULT=SCOPE_VIOLATION" "$out"
hasnt "committed in-scope edit: file.txt not flagged as outside scope" "outside scope" "$out"

# 2b: agy commits an out-of-scope file and a pnpm-lock.yaml
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EDIT=$'other.txt:out_scope\npnpm-lock.yaml:lock'
export FAKE_TASK_COMMIT=1
out="$("$TASK" run --name cmoutscope --task "$R/task.txt" --repo "$R" --scope "file.txt" 2>"$R/cmoutscope.err")"
rc=$?
eq "committed out-of-scope and forbidden -> exit 8" "8" "$rc"
has "committed out-of-scope: HEAD-moved violation" "violation: agy moved HEAD (committed):" "$out"
has "committed out-of-scope: other.txt flagged" "violation: other.txt (outside scope)" "$out"
has "committed forbidden: pnpm-lock.yaml flagged" "violation: pnpm-lock.yaml" "$out"
unset FAKE_TASK_COMMIT FAKE_TASK_EDIT

# Defect 4: agy-run stdout noise does not leak into agy-task stdout
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_STDOUT_NOISE="noisy stdout from agy-run"
out="$("$TASK" run --name noise --task "$R/task.txt" --repo "$R" 2>"$R/noise.err")"
rc=$?
eq "stdout noise: exit 0" "0" "$rc"
summary_file="$(cat "$R/.agy-sessions/noise.summary.txt")"
eq "stdout noise: agy-task stdout byte-identical to summary file" "$summary_file" "$out"
has "stdout noise: noise redirected to stderr" "noisy stdout from agy-run" "$(cat "$R/noise.err")"
unset FAKE_STDOUT_NOISE

# Defect 5: Worktree handling
# 5a: git worktree add failure captures and logs stderr
R="$(task_repo)"
echo "task" > "$R/task.txt"
touch "$R/.git/worktrees"
out="$("$TASK" run --name wtfail --task "$R/task.txt" --repo "$R" 2>&1)"; rc=$?
eq "git worktree add failure -> exit 2" "2" "$rc"
has "git worktree add failure: error logged" "failed to create worktree" "$out"
has "git worktree add failure: git stderr captured" "fatal: could not create leading directories" "$out"
rm -f "$R/.git/worktrees"

# 5b: Reusing invalid worktree paths with --reuse-worktree
R="$(task_repo)"
echo "task" > "$R/task.txt"
mkdir -p "$R/.worktrees"
touch "$R/.worktrees/agy-reuse-file"
out="$("$TASK" run --name reuse-file --task "$R/task.txt" --repo "$R" --reuse-worktree 2>&1)"; rc=$?
eq "reuse file as worktree -> exit 2" "2" "$rc"
has "reuse file: clear error message" "existing path is not a git worktree" "$out"

mkdir -p "$R/.worktrees/agy-reuse-dir"
out="$("$TASK" run --name reuse-dir --task "$R/task.txt" --repo "$R" --reuse-worktree 2>&1)"; rc=$?
eq "reuse plain dir as worktree -> exit 2" "2" "$rc"
has "reuse plain dir: clear error message" "existing path is not a git worktree" "$out"

R_OTHER="$(task_repo)"
git -C "$R_OTHER" worktree add -b foreign "$R/.worktrees/agy-reuse-foreign" HEAD >/dev/null 2>&1
out="$("$TASK" run --name reuse-foreign --task "$R/task.txt" --repo "$R" --reuse-worktree 2>&1)"; rc=$?
eq "reuse worktree of foreign repo -> exit 2" "2" "$rc"
has "reuse foreign worktree: clear error message" "does not belong to main repository" "$out"

# Defect 6: errexit and untracked files on AGY_FAILED
# 6a: AGY_FAILED lists untracked files under changed files
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EXIT=1
export FAKE_TASK_EDIT="untracked_fail.txt:created"
out="$("$TASK" run --name agyfail-untracked --task "$R/task.txt" --repo "$R" 2>"$R/agyfail-untracked.err")"
rc=$?
eq "stub agy-run exit 1 with untracked file: exit 1" "1" "$rc"
has "stub agy-run exit 1: summary shows untracked file" "?? untracked_fail.txt" "$out"
unset FAKE_TASK_EXIT FAKE_TASK_EDIT

# 6b: no set -e / set +e re-enables in agy-task
eq "no set -e re-enables in agy-task" "0" "$(grep -c 'set -e' "$TASK" || true)"
eq "no set +e in agy-task" "0" "$(grep -c 'set +e' "$TASK" || true)"

# agy-task rm tests
# 1. clean worktree whose branch has no unique commits -> removed without -f, logs/summary kept, prompt file gone
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
"$TASK" run --name rmclean --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "rm clean: run exit 0" "0" "$?"
eq "rm clean: worktree exists before rm" "yes" "$([ -d "$R/.worktrees/agy-rmclean" ] && echo yes || echo no)"
eq "rm clean: prompt file exists before rm" "yes" "$([ -f "$R/.agy-sessions/rmclean.prompt.txt" ] && echo yes || echo no)"
out="$("$TASK" rm rmclean --repo "$R" 2>"$R/rmclean.err")"; rc=$?
eq "rm clean: exit 0" "0" "$rc"
eq "rm clean: stdout line" "removed: worktree $R/.worktrees/agy-rmclean, branch agy/rmclean" "$out"
has "rm clean: stderr has progress" "[agy-task] removing worktree" "$(cat "$R/rmclean.err")"
eq "rm clean: worktree gone" "no" "$([ -e "$R/.worktrees/agy-rmclean" ] && echo yes || echo no)"
eq "rm clean: branch gone" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmclean" && echo yes || echo no)"
eq "rm clean: prompt file gone" "no" "$([ -f "$R/.agy-sessions/rmclean.prompt.txt" ] && echo yes || echo no)"
eq "rm clean: summary kept" "yes" "$([ -f "$R/.agy-sessions/rmclean.summary.txt" ] && echo yes || echo no)"
eq "rm clean: jsonl kept" "yes" "$([ -f "$R/.agy-sessions/rmclean.jsonl" ] && echo yes || echo no)"
eq "rm clean: setup log kept" "yes" "$([ -f "$R/.agy-sessions/rmclean.setup.log" ] && echo yes || echo no)"

# 2. dirty worktree -> refused (exit 2, worktree still there), with -f removed
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmdirty --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
echo "dirty edit" >> "$R/.worktrees/agy-rmdirty/file.txt"
out="$("$TASK" rm rmdirty --repo "$R" 2>"$R/rmdirty.err")"; rc=$?
eq "rm dirty without -f -> exit 2" "2" "$rc"
has "rm dirty: stderr mentions uncommitted" "uncommitted changes" "$(cat "$R/rmdirty.err")"
has "rm dirty: stderr mentions -f" "-f" "$(cat "$R/rmdirty.err")"
eq "rm dirty: worktree still there" "yes" "$([ -d "$R/.worktrees/agy-rmdirty" ] && echo yes || echo no)"
out="$("$TASK" rm rmdirty -f --repo "$R" 2>"$R/rmdirty_force.err")"; rc=$?
eq "rm dirty with -f -> exit 0" "0" "$rc"
eq "rm dirty: worktree gone with -f" "no" "$([ -e "$R/.worktrees/agy-rmdirty" ] && echo yes || echo no)"
eq "rm dirty: branch gone with -f" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmdirty" && echo yes || echo no)"

# 3. untracked non-ignored file -> refused
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmuntracked --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
echo "untracked" > "$R/.worktrees/agy-rmuntracked/untracked.txt"
out="$("$TASK" rm rmuntracked --repo "$R" 2>"$R/rmuntracked.err")"; rc=$?
eq "rm untracked file without -f -> exit 2" "2" "$rc"
has "rm untracked: stderr mentions untracked" "untracked files" "$(cat "$R/rmuntracked.err")"
has "rm untracked: stderr mentions -f" "-f" "$(cat "$R/rmuntracked.err")"
eq "rm untracked: worktree still there" "yes" "$([ -d "$R/.worktrees/agy-rmuntracked" ] && echo yes || echo no)"
"$TASK" rm rmuntracked -f --repo "$R" >/dev/null 2>&1
eq "rm untracked with -f: worktree gone" "no" "$([ -e "$R/.worktrees/agy-rmuntracked" ] && echo yes || echo no)"

# 4. branch with an unmerged commit -> refused, with -f removed
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmunmerged --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
echo "commit edit" >> "$R/.worktrees/agy-rmunmerged/file.txt"
git -C "$R/.worktrees/agy-rmunmerged" -c user.name=t -c user.email=t@t commit -am "unique commit" >/dev/null
out="$("$TASK" rm rmunmerged --repo "$R" 2>"$R/rmunmerged.err")"; rc=$?
eq "rm unmerged branch without -f -> exit 2" "2" "$rc"
has "rm unmerged: stderr mentions not reachable" "not reachable" "$(cat "$R/rmunmerged.err")"
has "rm unmerged: stderr mentions -f" "-f" "$(cat "$R/rmunmerged.err")"
eq "rm unmerged: worktree still there" "yes" "$([ -d "$R/.worktrees/agy-rmunmerged" ] && echo yes || echo no)"
eq "rm unmerged: branch still there" "yes" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmunmerged" && echo yes || echo no)"
out="$("$TASK" rm rmunmerged -f --repo "$R" 2>/dev/null)"; rc=$?
eq "rm unmerged with -f -> exit 0" "0" "$rc"
eq "rm unmerged: worktree gone with -f" "no" "$([ -e "$R/.worktrees/agy-rmunmerged" ] && echo yes || echo no)"
eq "rm unmerged: branch gone with -f" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmunmerged" && echo yes || echo no)"

# 5. worktree gone but branch left -> branch removed
R="$(task_repo)"
git -C "$R" branch agy/wtgone
out="$("$TASK" rm wtgone --repo "$R" 2>"$R/wtgone.err")"; rc=$?
eq "rm worktree gone branch left: exit 0" "0" "$rc"
eq "rm worktree gone branch left: stdout" "removed: branch agy/wtgone" "$out"
eq "rm worktree gone branch left: branch gone" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/wtgone" && echo yes || echo no)"

# 6. nothing exists -> exit 2
R="$(task_repo)"
out="$("$TASK" rm nothing --repo "$R" 2>"$R/nothing.err")"; rc=$?
eq "rm nothing exists -> exit 2" "2" "$rc"
has "rm nothing exists: stderr mentions nothing to remove" "nothing to remove" "$(cat "$R/nothing.err")"

# 7. invalid NAME -> exit 2
R="$(task_repo)"
"$TASK" rm BAD_NAME --repo "$R" >/dev/null 2>&1
eq "rm bad name (uppercase) -> exit 2" "2" "$?"
"$TASK" rm bad_name --repo "$R" >/dev/null 2>&1
eq "rm bad name (underscore) -> exit 2" "2" "$?"
"$TASK" rm --repo "$R" >/dev/null 2>&1
eq "rm missing name -> exit 2" "2" "$?"

# 8. called from inside a linked worktree -> resolves to the main checkout
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmtarget --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
mkdir -p "$R/.worktrees"
git -C "$R" worktree add -b agy/caller "$R/.worktrees/agy-caller" HEAD >/dev/null 2>&1
out="$( (cd "$R/.worktrees/agy-caller" && "$TASK" rm rmtarget 2>"$R/rmtarget.err") )"; rc=$?
eq "rm inside linked worktree: exit 0" "0" "$rc"
eq "rm inside linked worktree: stdout" "removed: worktree $R/.worktrees/agy-rmtarget, branch agy/rmtarget" "$out"
eq "rm inside linked worktree: worktree gone" "no" "$([ -e "$R/.worktrees/agy-rmtarget" ] && echo yes || echo no)"
eq "rm inside linked worktree: branch gone" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmtarget" && echo yes || echo no)"
git -C "$R" worktree remove --force "$R/.worktrees/agy-caller" >/dev/null 2>&1
git -C "$R" branch -D agy/caller >/dev/null 2>&1

# agy-task usage log tests
R="$(task_repo)"
echo "task" > "$R/task.txt"

# First run: header + 1 line with tokens 12345
"$TASK" run --name ulog1 --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: file exists" "yes" "$([ -f "$R/.agy-sessions/usage.tsv" ] && echo yes || echo no)"
expected_hdr=$'timestamp\tname\tresult\tagy_status\tturns\ttokens\tagy_seconds\texit_code'
actual_hdr="$(head -n 1 "$R/.agy-sessions/usage.tsv")"
eq "usage log: header line matches" "$expected_hdr" "$actual_hdr"
eq "usage log: line count after run 1" "2" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
line1_data="$(sed -n '2p' "$R/.agy-sessions/usage.tsv")"
eq "usage log run 1: name" "ulog1" "$(echo "$line1_data" | cut -f2)"
eq "usage log run 1: result" "RESULT=OK" "$(echo "$line1_data" | cut -f3)"
eq "usage log run 1: tokens" "12345" "$(echo "$line1_data" | cut -f6)"
eq "usage log run 1: exit code" "0" "$(echo "$line1_data" | cut -f8)"

# Second run appends (header still once)
"$TASK" run --name ulog2 --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: line count after run 2" "3" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
actual_hdr2="$(head -n 1 "$R/.agy-sessions/usage.tsv")"
eq "usage log: header line still once" "$expected_hdr" "$actual_hdr2"
line2_data="$(sed -n '3p' "$R/.agy-sessions/usage.tsv")"
eq "usage log run 2: name" "ulog2" "$(echo "$line2_data" | cut -f2)"
eq "usage log run 2: result" "RESULT=OK" "$(echo "$line2_data" | cut -f3)"
eq "usage log run 2: exit code" "0" "$(echo "$line2_data" | cut -f8)"

# Setup failure appends line with exit code 7
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'exit 1' )
EOF
"$TASK" run --name ulog-sfail --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: line count after setup fail" "4" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
line3_data="$(sed -n '4p' "$R/.agy-sessions/usage.tsv")"
eq "usage log sfail: name" "ulog-sfail" "$(echo "$line3_data" | cut -f2)"
eq "usage log sfail: result" "RESULT=SETUP_FAILED" "$(echo "$line3_data" | cut -f3)"
eq "usage log sfail: agy_status" "not run" "$(echo "$line3_data" | cut -f4)"
eq "usage log sfail: turns" "-" "$(echo "$line3_data" | cut -f5)"
eq "usage log sfail: tokens" "-" "$(echo "$line3_data" | cut -f6)"
eq "usage log sfail: exit code" "7" "$(echo "$line3_data" | cut -f8)"
rm -f "$R/.agy-sessions/agy-task.conf"

# agy-run failure appends line with right exit code
export FAKE_TASK_EXIT=1
"$TASK" run --name ulog-afail --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: line count after agy fail" "5" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
line4_data="$(sed -n '5p' "$R/.agy-sessions/usage.tsv")"
eq "usage log afail: name" "ulog-afail" "$(echo "$line4_data" | cut -f2)"
eq "usage log afail: result" "RESULT=AGY_FAILED" "$(echo "$line4_data" | cut -f3)"
eq "usage log afail: exit code" "1" "$(echo "$line4_data" | cut -f8)"
unset FAKE_TASK_EXIT

unset AGY_RUN


exit 0
