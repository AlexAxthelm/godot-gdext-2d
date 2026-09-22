//! The `TicTacToe` node: the thin translator between the Godot scene and
//! `tictactoe_core`.
//!
//! Per `DESIGN_PRINCIPLES.md` #2, this holds **no rules**. It owns a
//! `core::Board`, turns `#[func]` calls from the scene into `Board` moves, and
//! reports results back as signals the scene's GDScript view reacts to. Whose
//! turn it is, who won, and whether a move is legal are all decided by the core.
//!
//! Signals carry *tokens*, not phrasing: `"X"`, `"O"`, `"draw"`. The view is
//! responsible for turning those into user-facing text ("X's turn", "O wins!"),
//! keeping presentation out of the binding.

use godot::prelude::*;
use tictactoe_core::{Board, GameState, Player};

/// The scene-facing game node. Base `Node` (non-visual): it is a child of the
/// `main.tscn` layout, not the layout itself — the `Control` root plus its
/// GDScript view own the widgets.
#[derive(GodotClass)]
#[class(base=Node)]
pub struct TicTacToe {
    board: Board,
    base: Base<Node>,
}

#[godot_api]
impl INode for TicTacToe {
    fn init(base: Base<Node>) -> Self {
        Self {
            board: Board::new(),
            base,
        }
    }
}

#[godot_api]
impl TicTacToe {
    /// A mark was placed: `idx` is the cell (0..=8), `mark` is `"X"` or `"O"`.
    /// Emitted once per successful [`Self::play`].
    #[signal]
    fn cell_changed(idx: i64, mark: GString);

    /// The game is still in progress and it is now `turn`'s move (`"X"`/`"O"`).
    #[signal]
    fn turn_changed(turn: GString);

    /// The game ended. `outcome` is the winner (`"X"`/`"O"`) or `"draw"`; `line`
    /// holds the three winning cell indices (empty on a draw) so the view can
    /// highlight them.
    #[signal]
    fn game_over(outcome: GString, line: PackedInt32Array);

    /// Attempt to place the current player's mark at `idx`. Returns whether the
    /// move was accepted; an illegal move (out of range, occupied, or after the
    /// game is over) is a no-op the view can silently ignore.
    ///
    /// The index arrives from the engine, so it goes through the core's
    /// bounds-safe `try_play` — never a path that could panic across the FFI
    /// boundary (a panic there aborts rather than unwinds).
    #[func]
    fn play(&mut self, idx: i64) -> bool {
        if idx < 0 {
            return false;
        }
        let idx = idx as usize;
        if self.board.try_play(idx).is_err() {
            return false;
        }
        // The mark just placed is whatever now occupies the cell.
        if let Some(player) = self.board.get(idx).flatten() {
            self.signals()
                .cell_changed()
                .emit(idx as i64, &GString::from(mark_str(player)));
        }
        self.emit_state();
        true
    }

    /// Clear the board back to an empty game with X to move, and broadcast the
    /// fresh state (a `turn_changed("X")`).
    #[func]
    fn reset(&mut self) {
        self.board.reset();
        self.emit_state();
    }

    /// The player to move (`"X"`/`"O"`), or `""` if the game is over. For the
    /// view's initial paint without waiting on a signal.
    #[func]
    fn current_turn(&self) -> GString {
        match self.board.state() {
            GameState::InProgress { turn } => GString::from(mark_str(turn)),
            _ => GString::new(),
        }
    }

    /// The mark in `idx` (`"X"`/`"O"`), or `""` if empty or out of range. Lets
    /// the view repaint a cell from scratch.
    #[func]
    fn cell_mark(&self, idx: i64) -> GString {
        if idx < 0 {
            return GString::new();
        }
        match self.board.get(idx as usize).flatten() {
            Some(player) => GString::from(mark_str(player)),
            None => GString::new(),
        }
    }

    /// Emit the signal that describes the board's current high-level state:
    /// `turn_changed` while in progress, `game_over` once decided.
    fn emit_state(&mut self) {
        match self.board.state() {
            GameState::InProgress { turn } => {
                self.signals()
                    .turn_changed()
                    .emit(&GString::from(mark_str(turn)));
            }
            GameState::Won { winner, line } => {
                self.signals()
                    .game_over()
                    .emit(&GString::from(mark_str(winner)), &line_to_packed(line));
            }
            GameState::Draw => {
                self.signals()
                    .game_over()
                    .emit(&GString::from("draw"), &PackedInt32Array::new());
            }
        }
    }
}

/// The scene-facing token for a player.
fn mark_str(player: Player) -> &'static str {
    match player {
        Player::X => "X",
        Player::O => "O",
    }
}

/// A winning line as a Godot int array, for the `game_over` signal.
fn line_to_packed(line: [usize; 3]) -> PackedInt32Array {
    let mut array = PackedInt32Array::new();
    for &cell in &line {
        array.push(cell as i32);
    }
    array
}
