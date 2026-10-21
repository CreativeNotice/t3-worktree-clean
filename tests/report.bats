#!/usr/bin/env bats
#
# report: read-only. Every case checks that nothing on disk changed as well as
# what was printed.

load test_helper

setup() {
  setup_t3
}

@test "report: another worktree with uncommitted changes is listed with its branch and file" {
  local here; here=$(make_worktree proj t3code-here)
  local other; other=$(make_worktree proj t3code-other)
  printf 'unsaved\n' >"$other/scratch.txt"

  cd "$here"
  run "$SCRIPT" report

  succeeded
  output_has "t3code-other (t3code-other)"
  output_has "scratch.txt"
  [ -f "$other/scratch.txt" ]
}

@test "report: the worktree you are standing in is not listed as dirty" {
  local here; here=$(make_worktree proj t3code-here)
  printf 'mine\n' >"$here/mine.txt"

  cd "$here"
  run "$SCRIPT" report

  succeeded
  output_lacks "mine.txt"
}

@test "report: dirty worktrees in other projects are listed too" {
  local here; here=$(make_worktree proj t3code-here)
  local far; far=$(make_worktree elsewhere t3code-far)
  printf 'x\n' >"$far/x.txt"

  cd "$here"
  run "$SCRIPT" report

  succeeded
  output_has "t3code-far" "x.txt"
}

@test "report: under the threshold it prints the count and no list" {
  local here; here=$(make_worktree proj t3code-here)
  make_worktree proj t3code-old >/dev/null
  add_thread proj t3code-old archived "old thread"

  cd "$here"
  run "$SCRIPT" report

  succeeded
  output_has "count: 1 (threshold 5)"
  output_lacks "would remove"
  [ -d "$(wt_path proj t3code-old)" ]
}

@test "report: at the threshold it lists what --apply would remove" {
  local here; here=$(make_worktree proj t3code-here)
  make_worktree proj t3code-old1 >/dev/null
  make_worktree proj t3code-old2 >/dev/null
  add_thread proj t3code-old1 archived "old one"
  add_thread proj t3code-old2 deleted "old two"

  cd "$here"
  run "$SCRIPT" report --threshold 2

  succeeded
  output_has "count: 2 (threshold 2)"
  output_has "would remove" "t3code-old1"
  output_has "t3code-old2"
  [ -d "$(wt_path proj t3code-old1)" ]
}

@test "report: the count covers only the current project" {
  local here; here=$(make_worktree proj t3code-here)
  make_worktree elsewhere t3code-x >/dev/null
  add_thread elsewhere t3code-x archived "not this project"

  cd "$here"
  run "$SCRIPT" report

  succeeded
  output_has "Archived or deleted worktrees in proj"
  output_line "count: 0 (threshold 5)"
}

@test "report: --project overrides the inferred project" {
  local here; here=$(make_worktree proj t3code-here)
  make_worktree elsewhere t3code-x >/dev/null
  add_thread elsewhere t3code-x archived "other project"

  cd "$here"
  run "$SCRIPT" report --project elsewhere

  succeeded
  output_has "Archived or deleted worktrees in elsewhere"
  output_line "count: 1 (threshold 5)"
}

@test "report: it ends with the branch report for the current repo" {
  local here; here=$(make_worktree proj t3code-here)
  make_branch "$(repo_for proj)" feature/done 0

  cd "$here"
  run "$SCRIPT" report

  succeeded
  output_has "== Branches with no worktree ==" "merged   feature/done"
}
