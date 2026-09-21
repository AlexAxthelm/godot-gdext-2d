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
- Where randomness is needed (tie-breaking, "easy" difficulty), use a **seedable**
  generator — a vetted small crate such as `rand_pcg` or `fastrand`, seeded
  explicitly so tests and any future replays are deterministic. Take the seed (or
  the RNG) as a parameter rather than reaching for OS entropy inside the core.
  See dependency guidance in `DESIGN_PRINCIPLES.md`.
- The scene gets a mode toggle (hot-seat vs. vs-robot) and, for robot turns,
  asks the core for a move instead of waiting on input.

## Status
Post-v1 (see `ROADMAP.md`). The `best_move` seam is noted in the core skeleton now.
