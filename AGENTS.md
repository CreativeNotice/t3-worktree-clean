# t3-worktree-clean

A single-file bash CLI that removes git worktrees left behind by archived T3
Code threads. `README.md` covers what it does and how to install it.

## Agent skills

### Issue tracker

Issues live in GitHub Issues at `CreativeNotice/t3-worktree-clean`, via the `gh`
CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using the default label strings. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and one `docs/adr/` at the repo root, both
created lazily if they are ever needed. See `docs/agents/domain.md`.

## Testing

Work on this repo is test-first. Red, then green, for anything that touches
behaviour.

1. Write the test that captures the behaviour, before the code that satisfies it.
2. Run it and confirm it fails, for the reason you expect. A test that passes on
   its first run has proved nothing.
3. Write the smallest change that makes it pass.
4. Run the whole suite.

The harness is [bats-core](https://github.com/bats-core/bats-core). Tests live in
`tests/` and run with `bats tests/`. Install it with `brew install bats-core`.

**Show the output.** Paste the failing run and then the passing run into the chat,
and into the GitHub issue the work belongs to, before that issue is closed. The
value of red/green is the evidence, and an assurance that a test was red first is
not evidence.

Exempt: README wording, comments, and anything else that cannot change behaviour.
Everything touching the script's logic is in scope, and the guard table most of
all: every confirmed bug in this repo so far has been a guard that failed to fire.
