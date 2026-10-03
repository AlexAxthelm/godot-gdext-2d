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

## Focus & the Reset button
The keyboard/gamepad cursor is the focused control's focus ring. The Reset button
sits just below the grid: `cursor_down` from any bottom-row cell focuses it, and
`cursor_up` returns to the cell you left. On game over the Reset button is focused
automatically, so `place` immediately starts a new game.

## Status
Phase 2 (done). The `cursor_*`, `place`, and `reset` actions are defined in
`godot/project.godot` with keyboard **and** gamepad events (incl. left-stick
motion). `place` and `reset` are handled per-event in `main.gd`'s `_input`;
`cursor_*` movement is polled and debounced in `_process` (immediate first step,
then a fixed cadence while held) so a held key/stick/D-pad steps across the grid
without spamming. `_input` still swallows `cursor_*` events to pre-empt Godot's
built-in `ui_*` navigation. Mouse and touch arrive independently as button
`pressed` signals. See `ROADMAP.md`.
