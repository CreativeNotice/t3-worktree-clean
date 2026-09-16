#!/usr/bin/env bats
#
# The guard table for a worktree git still recognises. Every confirmed bug in
# this repo so far has been a guard that failed to fire, so each one gets a
# case that proves it does.

load test_helper

setup() {
  setup_t3
}

@test "guards: an active thread is skipped" {
  local wt; wt=$(make_worktree proj t3code-live)
  add_thread proj t3code-live active "live thread"

  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [[ "$output" == *"skip"*"thread still active"* ]]
}

@test "guards: the worktree you are standing in is skipped" {
  local wt; wt=$(make_worktree proj t3code-here)
  add_thread proj t3code-here archived "archived thread"

  cd "$wt"
  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [[ "$output" == *"skip"*"you are standing in it"* ]]
}

# SELF_WT resolves to the innermost repo, which is not necessarily the worktree
# under consideration. The physical-path check is what catches this.
@test "guards: standing in a nested repo inside a worktree still skips it" {
  local wt; wt=$(make_worktree proj t3code-here)
  add_thread proj t3code-here archived "archived thread"

  # Keep the checkout clean, so the skip cannot come from the dirty guard.
  printf 'vendor/\n' >"$wt/.gitignore"
  git -C "$wt" add .gitignore
  git -C "$wt" -c user.email=t@example.com -c user.name=t \
    commit -q -m "ignore vendor"
  mkdir -p "$wt/vendor/inner"
  git -C "$wt/vendor/inner" init -q -b main

  cd "$wt/vendor/inner"
  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [[ "$output" == *"skip"*"you are standing in it"* ]]
}

@test "guards: uncommitted changes are skipped" {
  local wt; wt=$(make_worktree proj t3code-dirty)
  add_thread proj t3code-dirty archived "archived thread"
  printf 'unsaved\n' >"$wt/scratch.txt"

  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [ -f "$wt/scratch.txt" ]
  [[ "$output" == *"skip"*"uncommitted change(s)"* ]]
}

@test "guards: a locked worktree is skipped" {
  local wt; wt=$(make_worktree proj t3code-locked)
  add_thread proj t3code-locked archived "archived thread"
  git -C "$(repo_for proj)" worktree lock "$wt"

  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [[ "$output" == *"skip"*"git worktree is locked"* ]]
}

@test "guards: a detached HEAD on no other ref is skipped" {
  local wt; wt=$(make_worktree proj t3code-detached)
  add_thread proj t3code-detached archived "archived thread"
  git -C "$wt" checkout -q --detach
  git -C "$wt" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m "unreachable work"

  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [[ "$output" == *"skip"*"detached HEAD, commits on no other ref"* ]]
}

@test "guards: --force removes a detached HEAD on no other ref" {
  local wt; wt=$(make_worktree proj t3code-detached)
  add_thread proj t3code-detached archived "archived thread"
  git -C "$wt" checkout -q --detach
  git -C "$wt" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m "unreachable work"

  run "$SCRIPT" --force --apply

  [ ! -d "$wt" ]
  [[ "$output" == *"FORCED, detached commits will be lost"* ]]
}

@test "guards: no thread record is skipped without --include-unknown" {
  local wt; wt=$(make_worktree proj t3code-nowhere)

  run "$SCRIPT" --apply

  [ -d "$wt" ]
  [[ "$output" == *"skip"*"no thread record (--include-unknown)"* ]]
}

@test "guards: an archived thread's clean worktree is removed" {
  local wt; wt=$(make_worktree proj t3code-old)
  add_thread proj t3code-old archived "archived thread"

  run "$SCRIPT" --apply

  [ ! -d "$wt" ]
  [[ "$output" == *"remove"*"archived"* ]]
  [[ "$output" == *"Removed 1 of 1"* ]]
}

@test "guards: removing a worktree keeps its branch" {
  local wt; wt=$(make_worktree proj t3code-old feat/keep-me)
  add_thread proj t3code-old archived "archived thread"

  run "$SCRIPT" --apply

  [ ! -d "$wt" ]
  git -C "$(repo_for proj)" rev-parse --verify -q feat/keep-me >/dev/null
}

@test "guards: a dry run removes nothing" {
  local wt; wt=$(make_worktree proj t3code-old)
  add_thread proj t3code-old archived "archived thread"

  run "$SCRIPT"

  [ -d "$wt" ]
  [[ "$output" == *"1 removable"* ]]
  [[ "$output" == *"Dry run"* ]]
}

@test "guards: --project limits the sweep to one project" {
  local keep; keep=$(make_worktree other t3code-other)
  local drop; drop=$(make_worktree proj t3code-old)
  add_thread other t3code-other archived "archived elsewhere"
  add_thread proj t3code-old archived "archived thread"

  run "$SCRIPT" --project proj --apply

  [ ! -d "$drop" ]
  [ -d "$keep" ]
}
