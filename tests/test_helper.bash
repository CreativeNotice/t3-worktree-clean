#!/usr/bin/env bash
#
# Fixture helpers for the t3-worktree-clean suite.
#
# Every test builds a throwaway T3_ROOT: a worktree root, a state database
# with the one table the script reads, and whatever checkouts the case needs.

# T3WC_SCRIPT replays the suite against another build of the script, which is
# how a case is shown red against the revision that had the bug.
SCRIPT="${T3WC_SCRIPT:-$BATS_TEST_DIRNAME/../t3-worktree-clean}"

# Build an empty T3 root and export T3_ROOT so the script points at it.
setup_t3() {
  T3_ROOT="$BATS_TEST_TMPDIR/t3"
  export T3_ROOT
  mkdir -p "$T3_ROOT/worktrees" "$T3_ROOT/userdata"

  # An orphan fixture is only orphaned if no ancestor is a git repository.
  # If the temp dir ever landed inside a clone, these tests would silently
  # stop testing what they claim to.
  if git -C "$T3_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "fixture root $T3_ROOT is inside a git work tree" >&2
    return 1
  fi

  # The database T3 reads and writes today. The worktree path lives in the
  # JSON payload, not in a column.
  sqlite3 "$T3_ROOT/userdata/statev2.sqlite" \
    'CREATE TABLE orchestration_v2_projection_threads (
       thread_id     TEXT PRIMARY KEY,
       title         TEXT NOT NULL,
       archived_at   TEXT,
       deleted_at    TEXT,
       payload_json  TEXT NOT NULL
     );'
}

# wt_path <project> <name> - the path the script will build for a worktree.
wt_path() {
  printf '%s' "$T3_ROOT/worktrees/$1/$2"
}

# sq <s> - the string with each single quote doubled, for a SQL literal.
sq() {
  printf '%s' "$1" | sed "s/'/''/g"
}

# state_sql <state> - the archived_at and deleted_at values for a thread state.
state_sql() {
  case "$1" in
    active) printf 'NULL, NULL' ;;
    archived) printf "'2026-01-01T00:00:00Z', NULL" ;;
    deleted) printf "NULL, '2026-01-01T00:00:00Z'" ;;
    *) echo "unknown thread state '$1'" >&2; return 1 ;;
  esac
}

# add_thread <project> <name> <active|archived|deleted> <title> [id]
# A root thread in statev2.sqlite, the database T3 uses now. Pass an id when a
# subagent will name this thread as its root.
add_thread() {
  local project="$1" name="$2" state="$3" title="$4" id="${5:-$2-$RANDOM$RANDOM}"
  insert_v2_thread "$project" "$name" "$state" "$title" "$id" \
    "json_object('parentThreadId', NULL, 'relationshipToParent', NULL,
                 'rootThreadId', '$(sq "$id")')"
}

# add_subagent <project> <name> <state> <title> <root-id> [parent-id] [id]
# A subagent thread, the kind T3 starts for a review or research run. It
# shares its root's worktree and records the root in its lineage. The parent
# defaults to the root; name another subagent to nest one.
add_subagent() {
  local project="$1" name="$2" state="$3" title="$4" root="$5"
  local parent="${6:-$5}" id="${7:-sub-$RANDOM$RANDOM}"
  insert_v2_thread "$project" "$name" "$state" "$title" "$id" \
    "json_object('parentThreadId', '$(sq "$parent")',
                 'relationshipToParent', 'subagent',
                 'rootThreadId', '$(sq "$root")')"
}

# add_fork <project> <name> <state> <title> <root-id>
# A thread forked from another, which the user starts and drives themselves.
add_fork() {
  local project="$1" name="$2" state="$3" title="$4" root="$5"
  insert_v2_thread "$project" "$name" "$state" "$title" "fork-$RANDOM$RANDOM" \
    "json_object('parentThreadId', '$(sq "$root")',
                 'relationshipToParent', 'fork',
                 'rootThreadId', '$(sq "$root")')"
}

# insert_v2_thread <project> <name> <state> <title> <id> <lineage-sql>
insert_v2_thread() {
  local project="$1" name="$2" state="$3" title="$4" id="$5" lineage="$6" cols
  cols=$(state_sql "$state") || return 1
  sqlite3 "$T3_ROOT/userdata/statev2.sqlite" \
    "INSERT INTO orchestration_v2_projection_threads
       (thread_id, title, archived_at, deleted_at, payload_json)
     VALUES ('$(sq "$id")', '$(sq "$title")', $cols,
       json_object('title', '$(sq "$title")',
                   'worktreePath', '$(sq "$(wt_path "$project" "$name")")',
                   'lineage', json($lineage)));"
}

# add_legacy_thread <project> <name> <active|archived|deleted> <title>
# A thread in state.sqlite, the database T3 used before statev2.sqlite.
add_legacy_thread() {
  local project="$1" name="$2" state="$3" title="$4" cols
  cols=$(state_sql "$state") || return 1
  sqlite3 "$T3_ROOT/userdata/state.sqlite" \
    'CREATE TABLE IF NOT EXISTS projection_threads (
       id            TEXT,
       title         TEXT,
       worktree_path TEXT,
       archived_at   TEXT,
       deleted_at    TEXT
     );'
  sqlite3 "$T3_ROOT/userdata/state.sqlite" \
    "INSERT INTO projection_threads (id, title, worktree_path, archived_at, deleted_at)
     VALUES ('$name', '$(sq "$title")', '$(sq "$(wt_path "$project" "$name")")', $cols);"
}

# drop_v2_db - an older T3 install, with no statev2.sqlite.
drop_v2_db() {
  rm -f "$T3_ROOT/userdata/statev2.sqlite"
}

# make_orphan <project> <name> - a plain directory git knows nothing about.
make_orphan() {
  local dir; dir=$(wt_path "$1" "$2")
  mkdir -p "$dir"
  printf 'work in progress\n' >"$dir/notes.txt"
  printf '%s' "$dir"
}

# make_worktree <project> <name> [branch] - a real git worktree of a real repo.
make_worktree() {
  local project="$1" name="$2" branch="${3:-$2}"
  local repo="$BATS_TEST_TMPDIR/repos/$project"
  if [ ! -d "$repo" ]; then
    mkdir -p "$repo"
    git -C "$repo" init -q -b main
    git -C "$repo" -c user.email=t@example.com -c user.name=t \
      commit -q --allow-empty -m "init"
  fi
  local dir; dir=$(wt_path "$project" "$name")
  mkdir -p "$(dirname "$dir")"
  git -C "$repo" worktree add -q -b "$branch" "$dir" main
  printf '%s' "$dir"
}

# repo_for <project> - the main repo backing that project's worktrees.
repo_for() {
  printf '%s' "$BATS_TEST_TMPDIR/repos/$1"
}

# break_checkout <dir> - what a real T3 worktree looks like once its .git
# file is gone: a directory on disk that git no longer recognises.
break_checkout() {
  rm -f "$1/.git"
}

# commit_on <dir> <message> - one empty commit in a checkout.
commit_on() {
  git -C "$1" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m "$2"
}

# make_branch <repo> <branch> [commits] - a branch off main with N commits of
# its own (default 0), never checked out anywhere.
make_branch() {
  local repo="$1" branch="$2" n="${3:-0}" i=0
  git -C "$repo" branch "$branch" main
  # Not `seq 1 $n`: macOS seq counts down, so `seq 1 0` prints 1 and 0.
  while [ "$i" -lt "$n" ]; do
    i=$((i + 1))
    git -C "$repo" -c user.email=t@example.com -c user.name=t \
      commit-tree -p "$branch" -m "$branch $i" "$branch^{tree}" \
      | xargs git -C "$repo" update-ref "refs/heads/$branch"
  done
}

# push_then_delete_remote <repo> <branch> - push the branch with tracking to a
# bare origin, then delete it there and prune, the way a host does once a PR
# completes. The local branch is left with a gone upstream.
push_then_delete_remote() {
  local repo="$1" branch="$2" origin="$BATS_TEST_TMPDIR/origin.git"
  [ -d "$origin" ] || git init -q --bare "$origin"
  git -C "$repo" remote get-url origin >/dev/null 2>&1 \
    || git -C "$repo" remote add origin "$origin"
  git -C "$repo" push -q -u origin "$branch" 2>/dev/null
  git -C "$repo" push -q origin --delete "$branch" 2>/dev/null
  git -C "$repo" fetch -q --prune origin
}

# Assertions that fail under the bash 3.2 macOS ships. There, a failing [[ ]]
# fails a test only on its last line, and `! cmd` never fails one, so a case
# written with either can pass while asserting nothing.

# output_has <s>... - $output contains each string, in the order given.
output_has() {
  local rest="$output" s
  for s in "$@"; do
    case "$rest" in
      *"$s"*) rest="${rest#*"$s"}" ;;
      *) printf 'output lacks "%s" (in order):\n%s\n' "$s" "$output" >&2; return 1 ;;
    esac
  done
}

# output_line <line> - $output has exactly this line. Substring matching is
# not enough for status words: "merged" is inside "unmerged".
output_line() {
  printf '%s\n' "$output" | grep -qxF -- "$1" \
    || { printf 'no line "%s" in:\n%s\n' "$1" "$output" >&2; return 1; }
}

# output_lacks <s> - $output does not contain the string.
output_lacks() {
  case "$output" in
    *"$1"*) printf 'output has "%s":\n%s\n' "$1" "$output" >&2; return 1 ;;
  esac
  return 0
}

# branch_exists / branch_missing <repo> <branch>
branch_exists() {
  git -C "$1" rev-parse --verify -q "refs/heads/$2" >/dev/null \
    || { echo "branch $2 is missing" >&2; return 1; }
}
branch_missing() {
  if git -C "$1" rev-parse --verify -q "refs/heads/$2" >/dev/null; then
    echo "branch $2 still exists" >&2; return 1
  fi
}

# succeeded - the last `run` exited 0.
succeeded() {
  [ "$status" -eq 0 ] || { printf 'exit %s:\n%s\n' "$status" "$output" >&2; return 1; }
}
