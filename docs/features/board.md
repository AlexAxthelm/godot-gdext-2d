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
Phase 0 ships the type skeleton (`Board`, `Player`, `Cell`, `GameState`).
Full move/win/draw logic is Phase 1 — see `ROADMAP.md`.
