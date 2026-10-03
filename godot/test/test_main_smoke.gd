extends GdUnitTestSuite

## Headless smoke test for the hot-seat scene.
##
## Proves the whole loop is wired: main.tscn loads, the TicTacToe extension node
## is reachable, and a cell press flows view → core → signal → repaint so the
## button text and status label update. This is the safety net for broken node
## references / renamed signals, and the seed for the Phase 5 headless-smoke CI
## job. Rules themselves are covered by the core's `cargo test`, not here.

const MAIN_SCENE := "res://main.tscn"


## Emit a cell button's `pressed` — the same signal a mouse click fires — so the
## test exercises the real view handler rather than calling the core directly.
func _press(cells: Array, idx: int) -> void:
	(cells[idx] as Button).pressed.emit()


func test_scene_starts_with_x_to_move() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var status: Label = runner.scene().get_node("%Status")
	assert_str(status.text).is_equal("X's turn")


func test_move_updates_cell_and_advances_turn() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var status: Label = scene.get_node("%Status")
	var cells := (scene.get_node("%Grid") as GridContainer).get_children()
	_press(cells, 0)
	assert_str((cells[0] as Button).text).is_equal("X")
	assert_str(status.text).is_equal("O's turn")


func test_win_announces_and_highlights_line() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var status: Label = scene.get_node("%Status")
	var cells := (scene.get_node("%Grid") as GridContainer).get_children()
	# X takes the top row (0,1,2); O plays harmless fillers (3,4).
	for idx: int in [0, 3, 1, 4, 2]:
		_press(cells, idx)
	assert_str(status.text).is_equal("X wins!")
	for idx: int in [0, 1, 2]:
		assert_bool((cells[idx] as Button).modulate != Color.WHITE).is_true()


func test_reset_clears_board() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var status: Label = scene.get_node("%Status")
	var reset_button: Button = scene.get_node("%Reset")
	var cells := (scene.get_node("%Grid") as GridContainer).get_children()
	_press(cells, 0)
	reset_button.pressed.emit()
	assert_str((cells[0] as Button).text).is_equal("")
	assert_str(status.text).is_equal("X's turn")


# --- Input layer (cursor / place) ------------------------------------------
# These exercise the view's input handlers directly (InputEvents don't transport
# in headless mode), so they call the handlers and manipulate focus themselves.


func test_starts_with_a_cell_focused() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var cells: Array = scene.get("_cells")
	assert_bool(scene.get_viewport().gui_get_focus_owner() == cells[0]).is_true()


func test_cursor_navigation_moves_and_clamps() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	scene.call("_move_selection", 1, 0)  # right from 0 → 1
	assert_int(scene.get("_selected")).is_equal(1)
	scene.call("_move_selection", 0, 1)  # down → 4
	assert_int(scene.get("_selected")).is_equal(4)
	scene.call("_move_selection", -1, 0)  # left → 3
	scene.call("_move_selection", 0, -1)  # up → 0
	assert_int(scene.get("_selected")).is_equal(0)
	scene.call("_move_selection", -1, 0)  # left at edge → clamped
	scene.call("_move_selection", 0, -1)  # up at edge → clamped
	assert_int(scene.get("_selected")).is_equal(0)


func test_place_activates_the_focused_cell() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var cells: Array = scene.get("_cells")
	(cells[4] as Button).grab_focus()
	scene.call("_place_on_focused_cell")
	assert_str((cells[4] as Button).text).is_equal("X")


func test_place_ignores_non_cell_focus() -> void:
	# Regression for the Enter-on-Reset bug: place while a non-cell (the Reset
	# button) holds focus must not drop a mark on the grid.
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var cells: Array = scene.get("_cells")
	(scene.get_node("%Reset") as Button).grab_focus()
	scene.call("_place_on_focused_cell")
	for i: int in cells.size():
		assert_str((cells[i] as Button).text).is_equal("")


func test_play_rejects_out_of_range_indices() -> void:
	# Guards the bounds contract: a negative or oversized index is rejected and
	# leaves the board untouched (an `as usize` cast would truncate on wasm32).
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var board: TicTacToe = scene.get_node("%Board")
	var status: Label = scene.get_node("%Status")
	var cells: Array = scene.get("_cells")
	assert_bool(board.play(-1)).is_false()
	assert_bool(board.play(999)).is_false()
	for i: int in cells.size():
		assert_str((cells[i] as Button).text).is_equal("")
	assert_str(status.text).is_equal("X's turn")


func test_full_board_with_no_winner_is_a_draw() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var status: Label = scene.get_node("%Status")
	var cells := (scene.get_node("%Grid") as GridContainer).get_children()
	# A classic drawn game (same ordering the core's draw test uses).
	for idx: int in [0, 1, 2, 4, 3, 5, 7, 6, 8]:
		_press(cells, idx)
	assert_str(status.text).is_equal("Draw")


func test_down_from_bottom_row_reaches_reset_and_back() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var cells: Array = scene.get("_cells")
	var reset_button: Button = scene.get_node("%Reset")
	scene.call("_move_selection", 0, 1)  # 0 → 3
	scene.call("_move_selection", 0, 1)  # 3 → 6 (bottom row)
	scene.call("_move_selection", 0, 1)  # 6 → Reset
	assert_bool(scene.get_viewport().gui_get_focus_owner() == reset_button).is_true()
	scene.call("_move_selection", 0, -1)  # Reset → 6 (the cell we left)
	assert_bool(scene.get_viewport().gui_get_focus_owner() == cells[6]).is_true()


func test_game_over_focuses_the_reset_button() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var reset_button: Button = scene.get_node("%Reset")
	var cells := (scene.get_node("%Grid") as GridContainer).get_children()
	for idx: int in [0, 3, 1, 4, 2]:  # X wins the top row
		_press(cells, idx)
	assert_bool(scene.get_viewport().gui_get_focus_owner() == reset_button).is_true()


func test_direct_board_reset_repaints_the_view() -> void:
	# A direct core reset() (not via the view's reset handler) must still clear
	# marks and the win highlight, via the board_reset signal.
	var runner := scene_runner(MAIN_SCENE)
	var scene := runner.scene()
	var board: TicTacToe = scene.get_node("%Board")
	var cells := (scene.get_node("%Grid") as GridContainer).get_children()
	for idx: int in [0, 3, 1, 4, 2]:  # X wins the top row (marks + highlight)
		_press(cells, idx)
	board.reset()
	for i: int in [0, 1, 2]:
		assert_str((cells[i] as Button).text).is_equal("")
		assert_bool((cells[i] as Button).modulate == Color.WHITE).is_true()
