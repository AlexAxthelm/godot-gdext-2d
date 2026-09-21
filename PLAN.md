# Phase 1 — Pure core rules

## Context
Phase 0 (merged, PR #1) shipped the type skeleton: `Player`, `Cell`, `Board`,
`GameState` in `rust/core/src/lib.rs` with the bodies deliberately left empty and
the API shaped close to its Phase 1 target. Phase 1 fills those bodies in to make
the **complete, engine-free game**: move validation, win/draw detection, and the
high-level state machine — all unit-tested with zero Godot dependency, so the
Phase 2 binding has a finished, panic-safe API to translate against.

Scope is defined by `docs/ROADMAP.md` (Phase 1 block), the inline "Phase 1
(deferred)" comment in `lib.rs`, and the review note in `docs/features/board.md`.

## Approach

All work is in `rust/core/src/lib.rs` (plus test additions in the same file's
`mod tests`). No new files, no new dependencies (honors DESIGN_PRINCIPLES #5).

### 1. Move error type
Add a small error enum returned by `try_play`:
```rust
pub enum MoveError { OutOfBounds, CellOccupied, GameOver }
```
Derive `Debug, Clone, Copy, PartialEq, Eq`.

### 2. Bounds-safe accessor (`board.md` review finding)
`get(idx) -> Option<Cell>` — outer `None` = index out of range, inner value =
the cell (`Some(None)` empty, `Some(Some(p))` claimed). The existing panicking
`cell()` stays as the trusted-index fast path; `get()` is what engine/UI-sourced
indices go through so untrusted input never reaches the panic across the gdext
FFI boundary.

### 3. Turn model — derive, don't store
Whose turn it is is a pure function of the board: `X` moves first, so the player
to move is `X` when the filled-cell count is even, `O` when odd. This keeps
`Board` holding only `cells` (no duplicated/desyncable turn field) and matches
the skeleton. Add a private helper (e.g. `fn to_move(&self) -> Player`).

**Document the seam.** Add a comment on `to_move()` (and a pointer near the
`Board` struct's `cells` field) recording *why* turn is derived and *where an
explicit `to_move: Player` field would live* if a future non-alternating variant
(undo-two, handicap, double-move) ever breaks the parity assumption — i.e. the
field goes on `Board`, `try_play` flips it on success, and `reset()` restores it
to `Player::X`. This makes the derive-vs-store decision legible to future
maintainers without building the field now (DESIGN_PRINCIPLES #4).

### 4. Win/draw detection
- A `const WIN_LINES: [[usize; 3]; 8]` table (3 rows, 3 cols, 2 diagonals).
- `winner() -> Option<(Player, [usize; 3])>` — first line whose three cells hold
  the same non-empty player; returns that player and the line (UI highlights it).
- `is_draw() -> bool` — board full **and** no winner.

### 5. State machine
`state() -> GameState` computes the high-level status from the board:
`winner()` → `Won { winner, line }`; else `is_draw()` → `Draw`; else
`InProgress { turn: self.to_move() }`. `GameState` becomes a computed view rather
than separately-stored state.

### 6. `try_play`
`try_play(&mut self, idx: usize) -> Result<(), MoveError>`:
1. reject if game already over (`state()` is `Won`/`Draw`) → `GameOver`
2. reject `idx >= CELL_COUNT` → `OutOfBounds`
3. reject non-empty cell → `CellOccupied`
4. place `self.to_move()`'s mark; `Ok(())`

Turn enforcement falls out for free: the mark placed is always the derived
current player, so "playing out of turn" is structurally impossible via this API.

### 7. Keep the seams, don't build them
Per DESIGN_PRINCIPLES #4 and the roadmap (Robot mode is post-v1), do **not**
implement `best_move` now. Keep the existing seam comment pointing at
`gameplay-ai.md`.

### 8. Doc-comment upkeep
Update the "Phase 1 (deferred)" comment block and the `cell()` panic note to
reflect that `get()` now exists; update `docs/features/board.md` Status and
`docs/ROADMAP.md` Phase 1 → mark done (matching the Phase 0 "*(done)*" style).

## Tests (exhaustive — the milestone)
In `mod tests`, add coverage for:
- all **8 win lines** for X and representative lines for O;
- a full-board **draw**;
- **illegal moves**: out-of-bounds → `OutOfBounds`, occupied cell →
  `CellOccupied`, any move after game over → `GameOver`;
- **alternation**: X then O then X placements land the correct marks;
- `get()` returns `None` out of range and the right `Cell` in range;
- `state()` transitions: fresh → `InProgress{X}`, after one move →
  `InProgress{O}`, winning line → `Won`, full no-line → `Draw`;
- `winner()` returns the correct line indices, `is_draw()` false while playable.

## Critical files
- `rust/core/src/lib.rs` — all logic + tests.
- `docs/ROADMAP.md`, `docs/features/board.md` — status/doc updates.

## Verification
From `rust/`:
```
make check   # fmt + clippy (see Makefile)
make test    # cargo test -p tictactoe-core
```
Milestone (ROADMAP): `make test` covers the full rules; `core` has zero Godot
dependency (verify `rust/core/Cargo.toml` gains no deps).

## Workflow
- Do the work in a git worktree on branch `feat/rust-core`, created under
  `.claude/worktrees/` per the user's worktree preference.
- Leave changes in the working tree; **do not commit or push** (user commits).
