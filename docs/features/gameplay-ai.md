# Robot (AI) Mode
---
priority: high
depends: board, gameplay-hotseat
---

A single-player mode versus an AI opponent, planned as a fast-follow to hot-seat.
The core is structured to accept this without a refactor.

## Design
- A pure `best_move(&Board, Player) -> usize` in `tictactoe-core`, fully
  unit-testable. v1 stub picks the first empty (or random) cell; the real
  implementation is **minimax** (optionally depth-limited for "easy" difficulty).
- If randomness is needed, the core takes an injected `&mut impl FnMut() -> f32`
  rather than depending on the `rand` crate (see `DESIGN_PRINCIPLES.md`).
- The scene gets a mode toggle (hot-seat vs. vs-robot) and, for robot turns,
  asks the core for a move instead of waiting on input.

## Status
Post-v1 (see `ROADMAP.md`). The `best_move` seam is noted in the core skeleton now.
