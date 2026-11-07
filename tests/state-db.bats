#!/usr/bin/env bats
#
# Which T3 state database the script reads. T3 moved thread state from
# state.sqlite to statev2.sqlite and kept the old file, which still answers
# queries but no longer learns about new threads (#13).

load test_helper

setup() {
  setup_t3
}

@test "state-db: an archived thread in statev2.sqlite is removable" {
  local wt; wt=$(make_worktree proj t3-done)
  add_thread proj t3-done archived "finished thread"

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-done" "finished thread" "remove" "archived"
  [ ! -d "$wt" ]
}

@test "state-db: an active thread in statev2.sqlite is skipped as active" {
  local wt; wt=$(make_worktree proj t3-live)
  add_thread proj t3-live active "live thread"

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-live" "live thread" "skip" "thread still active"
  output_lacks "no thread record"
  [ -d "$wt" ]
}

@test "state-db: statev2.sqlite decides when both databases hold the path" {
  local wt; wt=$(make_worktree proj t3-both)
  add_legacy_thread proj t3-both archived "stale record"
  add_thread proj t3-both active "current record"

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-both" "skip" "thread still active"
  [ -d "$wt" ]
}

@test "state-db: a path only state.sqlite knows is unknown when statev2.sqlite exists" {
  local wt; wt=$(make_worktree proj t3-old)
  add_legacy_thread proj t3-old archived "old thread"

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-old" "no thread record"
  [ -d "$wt" ]
}

@test "state-db: without statev2.sqlite, state.sqlite is still read" {
  local wt; wt=$(make_worktree proj t3code-old)
  add_legacy_thread proj t3code-old archived "old thread"
  drop_v2_db

  run "$SCRIPT" --apply

  succeeded
  output_has "t3code-old" "old thread" "remove" "archived"
  [ ! -d "$wt" ]
}

@test "state-db: a path with a quote in it is matched" {
  local wt; wt=$(make_worktree "it's" t3-quote)
  add_thread "it's" t3-quote active "quoted project"

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-quote" "thread still active"
  [ -d "$wt" ]
}
