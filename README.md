# t3-worktree-clean

Removes git worktrees left behind by archived T3 Code threads.

T3 Code creates a git worktree for every thread, under
`~/.t3/worktrees/<project>/t3code-<id>/`. It does not remove that worktree when
the thread is archived. On my machine they had reached 19 worktrees and 8.3 GB,
nearly all of it `node_modules`.

This script finds the ones nothing is using anymore and deletes them. It is a
dry run unless you pass `--apply`.

## Install

Either option puts the command on your `PATH`. These use `~/.local/bin`, so
swap in whichever directory you already use.

### Symlink a clone

Pick this if you might read or change the script. The command points at your
clone, so `git pull` updates it and your own edits take effect immediately.

```sh
mkdir -p ~/.local/bin
git clone https://github.com/CreativeNotice/t3-worktree-clean.git
ln -s "$PWD/t3-worktree-clean/t3-worktree-clean" ~/.local/bin/t3-worktree-clean
```

`ln` needs an absolute path, which is what `$PWD` is doing there. A relative
one gives you a link that breaks the moment you run it from elsewhere. Keep the
clone somewhere permanent, since deleting it leaves a dead link behind.

### Download the script

Pick this if you just want the command.

```sh
mkdir -p ~/.local/bin
curl -o ~/.local/bin/t3-worktree-clean \
  https://raw.githubusercontent.com/CreativeNotice/t3-worktree-clean/main/t3-worktree-clean
chmod +x ~/.local/bin/t3-worktree-clean
```

Then confirm your shell finds it.

```sh
which t3-worktree-clean
```

If it finds nothing, that directory is not on your `PATH`. Add it in your shell
config, for example `export PATH="$HOME/.local/bin:$PATH"` in `~/.zshrc`.

## Usage

```sh
t3-worktree-clean                        # show what would be removed
t3-worktree-clean --apply                # actually remove it
t3-worktree-clean --project my-project   # limit to one project
```

A dry run prints what it found and stops.

```
WORKTREE           THREAD                               SIZE  VERDICT
my-project
  t3code-025ffcf1  Theme work                           1.5G  remove archived
  t3code-3ee6cb93  implement 4878                       747M  remove archived; branch feat/x kept (4 commit(s) not in main)
  t3code-0fab55f1  Sales orders                         731M  skip thread still active

16 removable, 7.6G reclaimable; 3 kept.
Dry run. Re-run with --apply to remove them.
```

### Options

| Flag | Effect |
|---|---|
| `--apply` | Remove the worktrees. Without it nothing is deleted. |
| `--project NAME` | Only look at one project under `~/.t3/worktrees/`. |
| `--include-unknown` | Also remove worktrees that have no thread in T3's database. |
| `--force` | Remove even when detached-HEAD commits would become unreachable. |
| `-h`, `--help` | Show help. |

## How it decides

T3 keeps thread state in `~/.t3/userdata/state.sqlite`. Its `projection_threads`
table maps each thread to a `worktree_path` and records `archived_at` and
`deleted_at`. A worktree whose thread is archived or deleted, while its
directory is still on disk, is a leftover.

The script reads that database with `sqlite3 -readonly`, so it never writes to
T3's state.

## What it will not touch

A worktree is skipped when any of these is true.

- Its thread is still active.
- It is the worktree you are standing in.
- It has uncommitted or untracked changes.
- Git has it locked.
- It is on a detached `HEAD` holding commits that no other ref contains.

Git occasionally loses track of a worktree: its `.git` file goes missing, or
the directory is a leftover shell that was never a checkout at all. The script
reports that as an orphan directory and removes it with `rm -rf`, since there
is no worktree for git to remove. The first two checks above still apply, and
so does the `--include-unknown` rule below, but the last three cannot — git
will not report changes, locks or commits for a directory it does not track.
So an orphan directory is removed whole, and anything in it that was never
committed goes with it.

**Removing a worktree never deletes its branch.** Committed work on a named
branch stays reachable and you can check it out again anywhere. The script
reports how far a branch is ahead of your default branch, but does not treat
that as a reason to stop.

One caveat on that count. If you squash-merge your pull requests, a branch that
has already shipped still looks ahead forever, because its individual commits
never land on the default branch. Read the number as information, not as a
warning.

Worktrees with no thread record at all are skipped by default, since the script
cannot tell whether something it does not know about is in use. Pass
`--include-unknown` to clear those too.

## Requirements

- `git`
- `sqlite3`, which ships with macOS
- `bash` 3.2 or newer, so the stock macOS shell is fine

Written for macOS. It should work anywhere T3 stores its data the same way. Set
`T3_ROOT` if yours lives somewhere other than `~/.t3`.

## License

MIT. See [LICENSE](LICENSE).
