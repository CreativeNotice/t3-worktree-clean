#!/usr/bin/env bats
#
# Subagent threads (#15). T3 starts them for review and research runs, on the
# same worktree as the thread that started them, and does not archive them
# when that thread is archived. A subagent therefore follows its root thread:
# it never keeps a worktree alive on its own once the root is finished.

load test_helper

setup() {
  setup_t3
}

@test "subagents: root archived and its subagent open, the worktree is removable" {
  local wt; wt=$(make_worktree proj t3-done)
  add_thread proj t3-done archived "Implement 4880" root-1
  add_subagent proj t3-done active "Standards review of 4880 diff" root-1

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-done" "remove" "archived"
  [ ! -d "$wt" ]
}

@test "subagents: root open and its subagent archived, the worktree is active" {
  local wt; wt=$(make_worktree proj t3-live)
  add_thread proj t3-live active "Implement 4881" root-1
  add_subagent proj t3-live archived "Spec review of 4881 diff" root-1

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-live" "skip" "thread still active"
  [ -d "$wt" ]
}

@test "subagents: another open root thread on the path keeps it active" {
  local wt; wt=$(make_worktree proj t3-shared)
  add_thread proj t3-shared archived "first thread" root-1
  add_subagent proj t3-shared active "review for the first" root-1
  add_thread proj t3-shared active "second thread" root-2

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-shared" "skip" "thread still active"
  [ -d "$wt" ]
}

@test "subagents: a subagent whose root is missing keeps the worktree active" {
  local wt; wt=$(make_worktree proj t3-lost)
  add_subagent proj t3-lost active "orphaned review" root-gone

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-lost" "skip" "thread still active"
  [ -d "$wt" ]
}

@test "subagents: a nested subagent follows the top root" {
  local wt; wt=$(make_worktree proj t3-nest)
  add_thread proj t3-nest archived "top thread" root-1
  add_subagent proj t3-nest active "middle run" root-1 root-1 sub-1
  add_subagent proj t3-nest active "inner run" root-1 sub-1

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-nest" "remove" "archived"
  [ ! -d "$wt" ]
}

@test "subagents: a root deleted with its subagent open is removable" {
  local wt; wt=$(make_worktree proj t3-gone)
  add_thread proj t3-gone deleted "deleted thread" root-1
  add_subagent proj t3-gone active "review of it" root-1

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-gone" "remove"
  [ ! -d "$wt" ]
}

@test "subagents: a fork is the user's own thread and keeps the worktree active" {
  local wt; wt=$(make_worktree proj t3-fork)
  add_thread proj t3-fork archived "original" root-1
  add_fork proj t3-fork active "forked thread" root-1

  run "$SCRIPT" --apply

  succeeded
  output_has "t3-fork" "skip" "thread still active"
  [ -d "$wt" ]
}

@test "subagents: the row shows the root thread's title, not a subagent's" {
  local wt; wt=$(make_worktree proj t3-title)
  add_thread proj t3-title active "Implement 4882" root-1
  add_subagent proj t3-title active "Standards review of 4882 diff" root-1

  run "$SCRIPT"

  succeeded
  output_has "t3-title" "Implement 4882" "thread still active"
  output_lacks "Standards review"
}
