//! Godot (gdext) binding for the tic-tac-toe core.
//!
//! This crate is a **thin translation layer**: it hosts the `#[gdextension]`
//! entry point and (from Phase 2 onward) a root `TicTacToe` node that turns
//! Godot input/UI events into calls on `tictactoe_core` and emits signals back
//! to the scene. Game *rules* never live here — they live in `tictactoe-core`.
//!
//! Phase 0 status: entry point only. The `TicTacToe` node, the `main.tscn` grid,
//! InputMap wiring, and signals are Phase 2 (see `docs/ROADMAP.md`).

use godot::prelude::*;

// The `tictactoe-core` dependency is declared in Cargo.toml and will be used by
// the `TicTacToe` node in Phase 2. Nothing references it yet, which is fine —
// an unused path dependency produces no warning.

struct TicTacToeExtension;

#[gdextension]
unsafe impl ExtensionLibrary for TicTacToeExtension {}
