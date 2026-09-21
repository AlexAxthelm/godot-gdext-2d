# Glossary
---
User- and code-facing terminology, kept consistent across code, docs, and UI.
This is a living document.
---

- **Board** — the 3x3 playing field; 9 cells indexed 0–8 in row-major order.
- **Cell** — a single square. Empty, or holding one player's mark.
- **Mark** — a player's symbol placed in a cell (X or O).
- **Player** — `X` or `O`. `X` always moves first.
- **Turn** — whose move it currently is.
- **Line** — any of the 8 winning triples (3 rows, 3 columns, 2 diagonals).
- **Win / Draw** — game-ending states: a completed line, or a full board with no line.
- **Hot-seat** — local two-player mode: both players share one device, alternating turns.
- **Robot mode** — planned single-player mode versus an AI opponent (post-v1).
- **Action** — an abstract input intent from Godot's InputMap (`cursor_up`,
  `place`, `reset`, …), decoupled from any specific device.
- **Core** — the `tictactoe-core` crate: pure game rules, no engine.
- **Binding** — the `tictactoe-godot` crate: the thin gdext translation layer.
- **gdext** — the `godot-rust/gdext` project, the Rust bindings to the Godot engine.
- **GDExtension** — Godot's native-extension mechanism; the `.gdextension` file
  maps each platform to the compiled Rust library.
