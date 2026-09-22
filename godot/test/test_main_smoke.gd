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
