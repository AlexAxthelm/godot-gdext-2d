extends Control

## Thin view for the hot-seat tic-tac-toe game.
##
## Holds no rules. It forwards cell presses to the `TicTacToe` core node
## (`%Board`) and repaints when that node signals back — see
## docs/DESIGN_PRINCIPLES.md #2. The core emits tokens ("X"/"O"/"draw"); this
## view is what turns them into user-facing text and highlights.

var _cells: Array[Button] = []
var _selected: int = 0  # cell the keyboard/gamepad cursor is on

@onready var _board: TicTacToe = %Board
@onready var _grid: GridContainer = %Grid
@onready var _status: Label = %Status
@onready var _reset_button: Button = %Reset


func _ready() -> void:
	# The grid's Button children, in order, are cells 0..8. Skip any non-Button
	# child so a future spacer/label can't become a null entry; assert the count
	# so a miswired scene fails loudly rather than mis-indexing later.
	for child: Node in _grid.get_children():
		if child is Button:
			_cells.append(child as Button)
	assert(_cells.size() == 9, "expected 9 cell buttons in %Grid")
	for i: int in _cells.size():
		_cells[i].pressed.connect(_on_cell_pressed.bind(i))
		_cells[i].focus_entered.connect(_on_cell_focused.bind(i))
	_reset_button.pressed.connect(_on_reset_pressed)
	_board.cell_changed.connect(_on_cell_changed)
	_board.turn_changed.connect(_on_turn_changed)
	_board.game_over.connect(_on_game_over)
	_board.reset()  # broadcast the initial state (turn_changed → "X")
	_cells[_selected].grab_focus()  # a focused cell so the first `place` has a target


## Handle the abstract input actions here in `_input` — ahead of the GUI's
## built-in ui_* focus navigation — so `cursor_*` drives the grid cursor and
## `reset` always restarts. `place` activates only the focused cell and otherwise
## falls through to the focused control (see `_place_on_focused_cell`). Mouse and
## touch are untouched (they arrive as button presses, not these actions).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		_on_reset_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("place"):
		_place_on_focused_cell()
	elif event.is_action_pressed("cursor_up"):
		_move_selection(0, -1)
	elif event.is_action_pressed("cursor_down"):
		_move_selection(0, 1)
	elif event.is_action_pressed("cursor_left"):
		_move_selection(-1, 0)
	elif event.is_action_pressed("cursor_right"):
		_move_selection(1, 0)


## Move the cursor within the 3x3 grid (clamped at the edges) and focus that
## cell, so the focus ring is the visible selection highlight.
func _move_selection(dx: int, dy: int) -> void:
	var col: int = clampi(_selected % 3 + dx, 0, 2)
	var row: int = clampi(_selected / 3 + dy, 0, 2)
	_selected = row * 3 + col
	_cells[_selected].grab_focus()
	get_viewport().set_input_as_handled()


## `place` activates the grid cell that currently holds focus. If focus is on
## another control (the Reset button) or nowhere, do nothing and let the event
## reach the GUI, so the focused control activates itself — otherwise Enter on
## Reset would place a mark instead of resetting.
func _place_on_focused_cell() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	for i: int in _cells.size():
		if _cells[i] == focused:
			_on_cell_pressed(i)
			get_viewport().set_input_as_handled()
			return


func _on_cell_focused(idx: int) -> void:
	_selected = idx  # keep the cursor in sync when focus moves (e.g. by mouse)


func _on_cell_pressed(idx: int) -> void:
	# No game-over guard needed: the core rejects moves once the game is decided
	# (play returns false and emits nothing), so a late press is already a no-op.
	_board.play(idx)


func _on_reset_pressed() -> void:
	_clear_board()
	_board.reset()


func _on_cell_changed(idx: int, mark: String) -> void:
	_cells[idx].text = mark


func _on_turn_changed(turn: String) -> void:
	_status.text = "%s's turn" % turn


func _on_game_over(outcome: String, line: PackedInt32Array) -> void:
	if outcome == "draw":
		_status.text = "Draw"
	else:
		_status.text = "%s wins!" % outcome
		for idx: int in line:
			_cells[idx].modulate = Color(0.6, 1.0, 0.6)


func _clear_board() -> void:
	for cell: Button in _cells:
		cell.text = ""
		cell.modulate = Color.WHITE
