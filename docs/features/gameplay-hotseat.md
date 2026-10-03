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

## UI
A 3x3 grid of buttons, a status label ("X's turn" / "O wins!" / "Draw"), and a
reset button, all in `main.tscn`. A thin, fully-typed `main.gd` view forwards
presses to the `TicTacToe` node and repaints on its `cell_changed`,
`turn_changed`, and `game_over` signals — holding no rules itself
(`DESIGN_PRINCIPLES.md` #2). The node emits tokens (`"X"`/`"O"`/`"draw"`) plus the
winning line; the view is what phrases them and highlights the line.

## Status
Phase 2 (done): playable hot-seat game in the editor and via `make run` on macOS,
covered by a headless GdUnit4 scene smoke test (`make smoke`). Depends on the full
core rules from Phase 1. See `ROADMAP.md`.
