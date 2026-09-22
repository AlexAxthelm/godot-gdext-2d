//! Pure, engine-free tic-tac-toe game logic.
//!
//! This crate has **no Godot dependency** and no I/O. It is the reusable core:
//! all game rules live here and are exercised by `cargo test` without an engine.
//! The Godot binding crate (`../godot`) drives this via a thin translation layer.
//!
//! Phase 1 status: the full rules are implemented here — move validation with
//! turn enforcement (`try_play`), win/draw detection (`winner` / `is_draw`), and
//! the high-level state machine (`state`). The API has no engine dependency and
//! is exercised entirely by `cargo test`.

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

/// The eight winning lines, each a triple of cell indices (rows, columns, then
/// the two diagonals). `winner()` scans this table.
const WIN_LINES: [[usize; 3]; 8] = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8], // rows
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8], // columns
    [0, 4, 8],
    [2, 4, 6], // diagonals
];

/// Why a `try_play` was rejected. Returning this instead of panicking is what
/// lets the Phase 2 Godot binding surface bad input as a recoverable result — a
/// panic unwinding across the gdext FFI boundary aborts the process.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MoveError {
    /// `idx` was outside `0..CELL_COUNT`.
    OutOfBounds,
    /// The target cell was already claimed.
    CellOccupied,
    /// The game is already won or drawn; no further moves are legal.
    GameOver,
}

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
    // The only stored state: the nine cells. Whose turn it is and whether the
    // game is over are *derived* from these (see `to_move` / `state`), so there
    // is no second field that could disagree with the marks on the board.
    //
    // Turn seam: if a future non-alternating variant (undo-two, handicap,
    // double-move) ever breaks the "turn == parity of filled cells" assumption,
    // an explicit `to_move: Player` field would live here on `Board`, be flipped
    // by `try_play` on a successful move, and be restored to `Player::X` by
    // `reset()`. We derive rather than store today because strict alternation
    // makes the field pure duplication (DESIGN_PRINCIPLES #4).
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
    /// Panics if `idx >= CELL_COUNT`. The index is trusted here: callers must
    /// pass `0..CELL_COUNT`. Untrusted indices (from the engine / UI) should go
    /// through [`Board::get`], which is bounds-safe, so a panic never unwinds
    /// across the gdext FFI boundary (which would abort rather than recover).
    pub fn cell(&self, idx: usize) -> Cell {
        self.cells[idx]
    }

    /// Bounds-safe read: `None` if `idx` is out of range, otherwise `Some(cell)`
    /// (where the inner value is `None` for an empty cell or `Some(player)` for a
    /// claimed one). This is the accessor for indices that originate outside the
    /// core — the Phase 2 Godot binding calls in from engine callbacks — so
    /// out-of-range input is a value, not a panic. Use [`Board::cell`] only for
    /// indices already known to be in range.
    pub fn get(&self, idx: usize) -> Option<Cell> {
        self.cells.get(idx).copied()
    }

    /// All cells, row-major.
    pub fn cells(&self) -> &[Cell; CELL_COUNT] {
        &self.cells
    }

    /// Clear the board back to empty.
    pub fn reset(&mut self) {
        self.cells = [None; CELL_COUNT];
    }

    /// The player whose move it is *while the game is in progress*.
    ///
    /// Derived, not stored: `X` moves first and turns strictly alternate, so the
    /// player to move is `X` when an even number of cells are filled and `O` when
    /// odd. Callers should only treat this as meaningful when the game is still
    /// in progress; `state()` gates it behind `GameState::InProgress`.
    ///
    /// See the turn-seam note on `Board::cells` for where an explicit turn field
    /// would go if a variant ever broke the parity assumption.
    fn to_move(&self) -> Player {
        let filled = self.cells.iter().filter(|c| c.is_some()).count();
        if filled % 2 == 0 {
            Player::X
        } else {
            Player::O
        }
    }

    /// The winner and the line they completed, or `None` if nobody has won.
    ///
    /// Returns the first matching line in `WIN_LINES` order. A single move can
    /// complete two lines at once (a center move finishing both diagonals), in
    /// which case only that first line is reported — enough for the UI to
    /// highlight a winning three, and the winner is the same either way.
    pub fn winner(&self) -> Option<(Player, [usize; 3])> {
        for line in WIN_LINES {
            if let Some(player) = self.cells[line[0]] {
                if self.cells[line[1]] == Some(player) && self.cells[line[2]] == Some(player) {
                    return Some((player, line));
                }
            }
        }
        None
    }

    /// True when the board is full and nobody has won.
    pub fn is_draw(&self) -> bool {
        self.cells.iter().all(|c| c.is_some()) && self.winner().is_none()
    }

    /// The high-level status of the game, computed from the board.
    ///
    /// A win takes precedence over a full board, so this checks `winner()` first,
    /// then a draw, then reports the game in progress with the current turn. The
    /// draw branch tests board-fullness inline rather than calling `is_draw()`,
    /// which would rescan `winner()` a second time.
    pub fn state(&self) -> GameState {
        if let Some((winner, line)) = self.winner() {
            GameState::Won { winner, line }
        } else if self.cells.iter().all(|c| c.is_some()) {
            GameState::Draw
        } else {
            GameState::InProgress {
                turn: self.to_move(),
            }
        }
    }

    /// Attempt to play the current player's mark at `idx`.
    ///
    /// On success the mark is placed and the turn advances implicitly (the next
    /// `to_move()` flips, since one more cell is filled). Turn enforcement is
    /// structural: the mark placed is always the derived current player, so
    /// "playing out of turn" cannot be expressed through this API.
    ///
    /// # Errors
    /// - [`MoveError::GameOver`] if the game is already won or drawn.
    /// - [`MoveError::OutOfBounds`] if `idx >= CELL_COUNT`.
    /// - [`MoveError::CellOccupied`] if the target cell is already claimed.
    ///
    /// Checks run in that order, so a move on a finished game reports `GameOver`
    /// even if the index is also out of range or occupied.
    pub fn try_play(&mut self, idx: usize) -> Result<(), MoveError> {
        if !matches!(self.state(), GameState::InProgress { .. }) {
            return Err(MoveError::GameOver);
        }
        if idx >= CELL_COUNT {
            return Err(MoveError::OutOfBounds);
        }
        if self.cells[idx].is_some() {
            return Err(MoveError::CellOccupied);
        }
        self.cells[idx] = Some(self.to_move());
        Ok(())
    }

    // --- Post-v1 seam -------------------------------------------------------
    // The planned robot mode adds an AI move-picker `best_move(&Board, Player)
    // -> usize` (minimax) here. It is deliberately not implemented before its
    // phase (DESIGN_PRINCIPLES #4). See docs/features/gameplay-ai.md.
}

/// High-level state of a game in progress.
///
/// This is a *computed view* of a `Board` (see [`Board::state`]), not separately
/// stored state.
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

    /// Play a sequence of indices in order, asserting each `try_play` succeeds.
    /// Marks alternate starting with X, matching normal play.
    fn play(indices: &[usize]) -> Board {
        let mut board = Board::new();
        for &idx in indices {
            board.try_play(idx).expect("move should be legal");
        }
        board
    }

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
        let mut board = play(&[0, 1, 2]);
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

    // --- Turn / alternation -------------------------------------------------

    #[test]
    fn marks_alternate_starting_with_x() {
        let board = play(&[0, 1, 2]); // X, O, X
        assert_eq!(board.cell(0), Some(Player::X));
        assert_eq!(board.cell(1), Some(Player::O));
        assert_eq!(board.cell(2), Some(Player::X));
    }

    #[test]
    fn state_reports_turn_while_in_progress() {
        let mut board = Board::new();
        assert_eq!(board.state(), GameState::InProgress { turn: Player::X });
        board.try_play(4).unwrap();
        assert_eq!(board.state(), GameState::InProgress { turn: Player::O });
        board.try_play(0).unwrap();
        assert_eq!(board.state(), GameState::InProgress { turn: Player::X });
    }

    // --- Wins: all eight lines ----------------------------------------------

    /// For each of the 8 win lines, drive X onto the whole line while O plays
    /// harmless cells elsewhere, and assert X wins on exactly that line.
    #[test]
    fn x_wins_on_every_line() {
        for line in WIN_LINES {
            // Three off-line cells for O's filler moves.
            let fillers: Vec<usize> = (0..CELL_COUNT).filter(|i| !line.contains(i)).collect();
            let mut board = Board::new();
            // X plays line[0], O filler, X line[1], O filler, X line[2].
            board.try_play(line[0]).unwrap();
            board.try_play(fillers[0]).unwrap();
            board.try_play(line[1]).unwrap();
            board.try_play(fillers[1]).unwrap();
            board.try_play(line[2]).unwrap();

            assert_eq!(
                board.winner(),
                Some((Player::X, line)),
                "X should win on line {line:?}"
            );
            assert_eq!(
                board.state(),
                GameState::Won {
                    winner: Player::X,
                    line
                }
            );
        }
    }

    #[test]
    fn o_can_win() {
        // O wins the right column [2,5,8]. Sequence: X0 O2 X1 O5 X3 O8.
        let board = play(&[0, 2, 1, 5, 3, 8]);
        assert_eq!(board.winner(), Some((Player::O, [2, 5, 8])));
        assert_eq!(
            board.state(),
            GameState::Won {
                winner: Player::O,
                line: [2, 5, 8]
            }
        );
    }

    #[test]
    fn no_winner_on_empty_or_partial_board() {
        assert_eq!(Board::new().winner(), None);
        let board = play(&[0, 4, 8]); // X0 O4 X8 — no line
        assert_eq!(board.winner(), None);
        assert!(!board.is_draw());
    }

    // --- Draw ---------------------------------------------------------------

    #[test]
    fn full_board_with_no_line_is_a_draw() {
        // A classic drawn game:
        //  X | O | X
        //  X | O | O
        //  O | X | X
        // Move order producing that layout, alternating X/O:
        let board = play(&[0, 1, 2, 4, 3, 5, 7, 6, 8]);
        assert!(board.is_draw());
        assert_eq!(board.winner(), None);
        assert_eq!(board.state(), GameState::Draw);
    }

    // --- Illegal moves ------------------------------------------------------

    #[test]
    fn out_of_bounds_move_is_rejected() {
        let mut board = Board::new();
        assert_eq!(board.try_play(CELL_COUNT), Err(MoveError::OutOfBounds));
        assert_eq!(board.try_play(999), Err(MoveError::OutOfBounds));
        // Rejected moves must not mutate the board.
        assert_eq!(board, Board::new());
    }

    #[test]
    fn occupied_cell_is_rejected() {
        let mut board = Board::new();
        board.try_play(4).unwrap();
        assert_eq!(board.try_play(4), Err(MoveError::CellOccupied));
        // Still O's turn, X's mark still there.
        assert_eq!(board.cell(4), Some(Player::X));
        assert_eq!(board.state(), GameState::InProgress { turn: Player::O });
    }

    #[test]
    fn moves_after_game_over_are_rejected() {
        // X wins on the top row, then any further move is GameOver.
        let mut board = play(&[0, 3, 1, 4, 2]); // X0 O3 X1 O4 X2 -> X wins row 0
        assert!(matches!(board.state(), GameState::Won { .. }));
        assert_eq!(board.try_play(5), Err(MoveError::GameOver)); // empty cell
        assert_eq!(board.try_play(0), Err(MoveError::GameOver)); // occupied cell
        assert_eq!(board.try_play(999), Err(MoveError::GameOver)); // oob
    }

    // --- get(): bounds-safe accessor ----------------------------------------

    #[test]
    fn get_is_bounds_safe() {
        let mut board = Board::new();
        board.try_play(0).unwrap(); // X at 0
        assert_eq!(board.get(0), Some(Some(Player::X)));
        assert_eq!(board.get(1), Some(None)); // in range, empty
        assert_eq!(board.get(CELL_COUNT), None); // out of range
        assert_eq!(board.get(999), None);
    }
}
