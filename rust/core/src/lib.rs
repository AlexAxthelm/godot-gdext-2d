//! Pure, engine-free tic-tac-toe game logic.
//!
//! This crate has **no Godot dependency** and no I/O. It is the reusable core:
//! all game rules live here and are exercised by `cargo test` without an engine.
//! The Godot binding crate (`../godot`) drives this via a thin translation layer.
//!
//! Phase 0 status: this is the *type skeleton* only. Win/draw detection and the
//! full move state machine land in Phase 1 (see `docs/ROADMAP.md`). The public
//! shape here is deliberately close to the target so Phase 1 fills bodies in
//! rather than reshaping the API.

/// The two players. `X` always moves first.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Player {
    X,
    O,
}

impl Player {
    /// The player whose turn follows this one.
    pub fn other(self) -> Player {
        match self {
            Player::X => Player::O,
            Player::O => Player::X,
        }
    }
}

/// A single square: empty, or claimed by a player.
pub type Cell = Option<Player>;

/// The number of cells on a standard 3x3 board.
pub const CELL_COUNT: usize = 9;

/// The 3x3 board, indexed 0..=8 in row-major order:
///
/// ```text
///  0 | 1 | 2
/// ---+---+---
///  3 | 4 | 5
/// ---+---+---
///  6 | 7 | 8
/// ```
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Board {
    cells: [Cell; CELL_COUNT],
}

impl Default for Board {
    fn default() -> Self {
        Self::new()
    }
}

impl Board {
    /// A fresh, empty board.
    pub fn new() -> Self {
        Board {
            cells: [None; CELL_COUNT],
        }
    }

    /// Read a single cell. Returns `None` for an empty cell.
    ///
    /// # Panics
    /// Panics if `idx >= CELL_COUNT`. The index is currently trusted: callers
    /// must pass `0..CELL_COUNT`. This matters because the Phase 2 Godot binding
    /// calls in from engine callbacks, and a panic unwinding across the gdext
    /// FFI boundary aborts rather than surfacing a recoverable error. Phase 1
    /// should add a bounds-safe accessor (e.g. `get(idx) -> Option<Cell>`)
    /// alongside the checked `try_play`, so untrusted input never reaches this
    /// panicking path. See the review note in the Phase 1 block below.
    pub fn cell(&self, idx: usize) -> Cell {
        self.cells[idx]
    }

    /// All cells, row-major.
    pub fn cells(&self) -> &[Cell; CELL_COUNT] {
        &self.cells
    }

    /// Clear the board back to empty.
    pub fn reset(&mut self) {
        self.cells = [None; CELL_COUNT];
    }

    // --- Phase 1 (deferred) -------------------------------------------------
    // The following belong to the full rules and will be implemented in Phase 1:
    //   - try_play(idx) -> Result<(), MoveError> with turn enforcement
    //   - get(idx) -> Option<Cell>: bounds-safe read so untrusted (engine/UI)
    //     indices never hit the panicking `cell()` above (review finding).
    //   - winner() -> Option<(Player, [usize; 3])>
    //   - is_draw() -> bool
    //   - GameState transitions
    // and an AI move-picker hook `best_move(&Board, Player) -> usize` for the
    // planned robot mode. See docs/features/gameplay-ai.md.
}

/// High-level state of a game in progress.
///
/// Phase 0: defined but not yet driven by the rules engine (Phase 1).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GameState {
    /// Game ongoing; `turn` is whose move it is.
    InProgress { turn: Player },
    /// `winner` won along the three cells in `line`.
    Won { winner: Player, line: [usize; 3] },
    /// Board full with no winner.
    Draw,
}

impl Default for GameState {
    fn default() -> Self {
        GameState::InProgress { turn: Player::X }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_board_is_empty() {
        let board = Board::new();
        assert!(board.cells().iter().all(|c| c.is_none()));
    }

    #[test]
    fn player_alternates() {
        assert_eq!(Player::X.other(), Player::O);
        assert_eq!(Player::O.other(), Player::X);
    }

    #[test]
    fn reset_clears_board() {
        let mut board = Board::new();
        // (Phase 1 will place marks via try_play; here we just prove reset works.)
        board.reset();
        assert_eq!(board, Board::new());
    }

    #[test]
    fn default_state_is_x_to_move() {
        assert_eq!(
            GameState::default(),
            GameState::InProgress { turn: Player::X }
        );
    }
}
