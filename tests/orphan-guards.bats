#!/usr/bin/env bats
#
# Issue #1: a directory git does not recognise took a branch of its own that
# ran before every guard, so it was removed with no safety check at all.
# An orphan is a worktree the script cannot reason about, which is a reason
# for more care, not less.

load test_helper

setup() {
  setup_t3
}

@test "orphan: active thread is skipped" {
  make_orphan proj t3code-live >/dev/null
  add_thread proj t3code-live active "live thread, broken checkout"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"t3code-live"* ]]
  [[ "$output" == *"skip"*"thread still active"* ]]
}

@test "orphan: --apply does not delete a directory whose thread is active" {
  local wt; wt=$(make_orphan proj t3code-live)
  add_thread proj t3code-live active "live thread, broken checkout"

  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ -d "$wt" ]
  [ -f "$wt/notes.txt" ]
  [[ "$output" == *"Removed 0 of 1"* ]]
}

@test "orphan: no thread record is skipped without --include-unknown" {
  local wt; wt=$(make_orphan proj t3code-nowhere)

  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ -d "$wt" ]
  [[ "$output" == *"skip"*"no thread record (--include-unknown)"* ]]
}

@test "orphan: no thread record is removed with --include-unknown" {
  local wt; wt=$(make_orphan proj t3code-nowhere)

  run "$SCRIPT" --include-unknown --apply

  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
  [[ "$output" == *"remove"*"orphan directory, not a git worktree"* ]]
}

@test "orphan: the directory you are standing in is skipped" {
  local wt; wt=$(make_orphan proj t3code-here)
  add_thread proj t3code-here archived "archived thread"

  cd "$wt"
  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ -d "$wt" ]
  [[ "$output" == *"skip"*"you are standing in it"* ]]
}

@test "orphan: a subdirectory of the one you are standing in is skipped" {
  local wt; wt=$(make_orphan proj t3code-here)
  add_thread proj t3code-here archived "archived thread"
  mkdir -p "$wt/src"

  cd "$wt/src"
  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ -d "$wt" ]
  [[ "$output" == *"skip"*"you are standing in it"* ]]
}

@test "orphan: a live thread's broken checkout survives --apply" {
  local wt; wt=$(make_worktree proj t3code-broken)
  break_checkout "$wt"
  add_thread proj t3code-broken active "live thread, broken checkout"

  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ -d "$wt" ]
  [[ "$output" == *"skip"*"thread still active"* ]]
}

@test "orphan: an archived thread's directory is still removed" {
  local wt; wt=$(make_orphan proj t3code-old)
  add_thread proj t3code-old archived "archived thread"

  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
  [[ "$output" == *"remove"*"orphan directory, not a git worktree"* ]]
  [[ "$output" == *"Removed 1 of 1"* ]]
}

@test "orphan: a deleted thread's directory is still removed" {
  local wt; wt=$(make_orphan proj t3code-gone)
  add_thread proj t3code-gone deleted "deleted thread"

  run "$SCRIPT" --apply

  [ "$status" -eq 0 ]
  [ ! -d "$wt" ]
  [[ "$output" == *"Removed 1 of 1"* ]]
}
