# Input Actions
---
priority: MVP
depends:
---

All input is routed through Godot's **InputMap actions**, never bound to a
single device. This keeps the core input-agnostic and makes multi-platform
(and future controller/console) support nearly free. See `DESIGN_PRINCIPLES.md`.

## Actions
- `cursor_up`, `cursor_down`, `cursor_left`, `cursor_right` — move the selection
  around the grid (keyboard arrows / WASD / D-pad / left stick).
- `place` — place a mark in the selected cell (Enter/Space / gamepad A / tap /
  mouse click on a cell).
- `reset` — start a new game (R / gamepad Start / reset button).

## Bindings
- **Mouse / touch**: direct hit on a cell button counts as select + `place`.
- **Keyboard**: arrows/WASD move; Enter/Space place; R resets.
- **Gamepad**: D-pad/stick move; A place; Start reset.

The `TicTacToe` node reads these actions and calls the core; the core only ever
receives "place at cell N."

## Status
Phase 2 (see `ROADMAP.md`).
