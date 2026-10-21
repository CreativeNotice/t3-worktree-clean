#!/usr/bin/env bats
#
# prune-branches: local branches no worktree has checked out. It deletes only
# what git -d can prove is merged, so most cases here check what it keeps.

load test_helper

setup() {
  setup_t3
  make_worktree proj t3code-base >/dev/null
  REPO=$(repo_for proj)
  cd "$REPO"
}

@test "prune-branches: a merged branch with no worktree is listed, and a dry run keeps it" {
  make_branch "$REPO" feature/done 0

  run "$SCRIPT" prune-branches

  succeeded
  output_line "merged   feature/done"
  branch_exists "$REPO" feature/done
}

@test "prune-branches: --apply deletes a merged branch and keeps an unmerged one" {
  make_branch "$REPO" feature/done 0
  make_branch "$REPO" feature/wip 2

  run "$SCRIPT" prune-branches --apply

  succeeded
  branch_missing "$REPO" feature/done
  branch_exists "$REPO" feature/wip
  output_line "deleted  feature/done"
  output_line "unmerged feature/wip (2 commit(s) not in main)"
}

@test "prune-branches: a branch a worktree has checked out is not listed" {
  run "$SCRIPT" prune-branches --apply

  succeeded
  output_lacks "t3code-base"
  branch_exists "$REPO" t3code-base
}

@test "prune-branches: the default branch is never listed" {
  # Park main's checkout elsewhere so no worktree holds it.
  git -C "$REPO" switch -q --detach

  run "$SCRIPT" prune-branches --apply

  succeeded
  output_lacks " main"
  branch_exists "$REPO" main
}

# A squash merge leaves the branch's commits off main, so git sees it as
# unmerged; the only local sign is that the host deleted the remote branch.
@test "prune-branches: a branch whose upstream is gone is marked gone and kept by --apply" {
  make_branch "$REPO" rm/42-squashed 1
  push_then_delete_remote "$REPO" rm/42-squashed

  run "$SCRIPT" prune-branches --apply

  succeeded
  output_line "gone     rm/42-squashed (1 commit(s) not in main; upstream deleted)"
  branch_exists "$REPO" rm/42-squashed
}

@test "prune-branches: --prefix limits the branches considered" {
  make_branch "$REPO" t3code/aaa 0
  make_branch "$REPO" other/bbb 0

  run "$SCRIPT" prune-branches --prefix t3code/

  succeeded
  output_line "merged   t3code/aaa"
  output_lacks "other/bbb"
}

@test "prune-branches: --apply prunes a vanished worktree, freeing its merged branch" {
  local wt; wt=$(make_worktree proj t3code-gone)
  rm -rf "$wt"

  run "$SCRIPT" prune-branches --apply

  succeeded
  output_line "deleted  t3code-gone"
  branch_missing "$REPO" t3code-gone
}

@test "prune-branches: run from a linked worktree, it reads the main checkout" {
  make_branch "$REPO" feature/done 0
  cd "$(wt_path proj t3code-base)"

  run "$SCRIPT" prune-branches

  succeeded
  output_line "merged   feature/done"
}

# git branch -d judges against HEAD, and the main checkout need not be on the
# default branch. Ancestry of the default branch is the test that matters.
@test "prune-branches: --apply deletes a merged branch while the main checkout is on another branch" {
  make_branch "$REPO" feature/done 0
  make_branch "$REPO" feature/elsewhere 1
  git -C "$REPO" switch -q feature/elsewhere
  # Move main and feature/done ahead together, so HEAD does not contain it.
  git -C "$REPO" update-ref refs/heads/main \
    "$(git -C "$REPO" -c user.email=t@example.com -c user.name=t commit-tree -p main -m ahead 'main^{tree}')"
  git -C "$REPO" update-ref refs/heads/feature/done main

  run "$SCRIPT" prune-branches --apply

  succeeded
  output_line "deleted  feature/done"
  branch_missing "$REPO" feature/done
}
