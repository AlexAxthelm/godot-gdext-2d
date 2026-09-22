# Board & Rules
---
priority: MVP
depends:
---

The board is the 3x3 grid and the rules that govern it. It lives entirely in
`tictactoe-core` with no engine dependency (see `DESIGN_PRINCIPLES.md`).

## Model
- 9 cells, indexed 0–8 row-major (see `GLOSSARY.md`).
- A cell is empty or holds one player's mark.
- `Player::X` moves first; turns alternate.

## Rules
- A move places the current player's mark in an empty cell; playing an occupied
  cell or playing out of turn is rejected.
- The game ends when a player completes one of the 8 lines (win) or the board
  fills with no line (draw).
- `winner()` reports both the winning player and the winning line (so the UI can
  highlight it).

## Status
Phase 1 (done) implements the full rules in `tictactoe-core`: `try_play(idx)`
with turn enforcement and `MoveError` rejection, `winner()`, `is_draw()`, and
`state()`. Whose turn it is is derived from cell parity rather than stored. See
`ROADMAP.md`.

Note: `Board::cell(idx)` still panics on an out-of-range index — it's the trusted
fast path. Indices coming from the engine / UI go through the bounds-safe
`get(idx) -> Option<Cell>` (outer `None` = out of range) so they can't reach that
panicking path (a panic across the gdext FFI boundary aborts rather than
recovering). The Phase 2 `TicTacToe` node does exactly this — its `play(idx)`
routes engine indices through `try_play`/`get`, never `cell`.
