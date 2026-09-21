# Hot-seat Play
---
priority: MVP
depends: board, input-actions
---

Local two-player mode: X and O share one device and alternate turns. This is the
first complete, shippable game and the vehicle for proving the pipeline.

## Flow
1. Empty board, X to move.
2. Active player selects an empty cell (via any input — see `input-actions.md`).
3. Mark is placed; turn passes to the other player.
4. On a win, highlight the winning line and announce the winner; on a full board
   with no line, announce a draw.
5. Reset returns to an empty board with X to move.

## UI (Phase 2)
A 3x3 grid of buttons, a status label ("X's turn" / "O wins!" / "Draw"), and a
reset button, all in `main.tscn`. The scene reacts to `cell_changed` and
`game_over` signals from the `TicTacToe` node.

## Status
Phase 2 (see `ROADMAP.md`). Depends on the full core rules from Phase 1.
