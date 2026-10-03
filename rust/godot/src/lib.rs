//! Godot (gdext) binding for the tic-tac-toe core.
//!
//! This crate is a **thin translation layer**: it hosts the `#[gdextension]`
//! entry point and (from Phase 2 onward) a root `TicTacToe` node that turns
//! Godot input/UI events into calls on `tictactoe_core` and emits signals back
//! to the scene. Game *rules* never live here — they live in `tictactoe-core`.
//!
//! Phase 2 status: the `#[gdextension]` entry point plus the [`node::TicTacToe`]
//! node — the translator that turns engine calls into `tictactoe_core` moves and
//! emits signals back to the scene. The `main.tscn` grid and InputMap wiring live
//! on the Godot side (see `docs/ROADMAP.md`).

use godot::prelude::*;

mod node;

struct TicTacToeExtension;

#[gdextension]
unsafe impl ExtensionLibrary for TicTacToeExtension {}
