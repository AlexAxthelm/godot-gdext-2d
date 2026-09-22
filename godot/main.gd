extends Control

## Thin view for the hot-seat tic-tac-toe game.
##
## Holds no rules. It forwards cell presses to the `TicTacToe` core node
## (`%Board`) and repaints when that node signals back — see
## docs/DESIGN_PRINCIPLES.md #2. The core emits tokens ("X"/"O"/"draw"); this
## view is what turns them into user-facing text and highlights.

var _cells: Array[Button] = []
var _game_over: bool = false
var _selected: int = 0  # cell the keyboard/gamepad cursor is on

@onready var _board: TicTacToe = %Board
@onready var _grid: GridContainer = %Grid
@onready var _status: Label = %Status
@onready var _reset_button: Button = %Reset


func _ready() -> void:
	for child: Node in _grid.get_children():
		_cells.append(child as Button)
	for i: int in _cells.size():
		_cells[i].pressed.connect(_on_cell_pressed.bind(i))
		_cells[i].focus_entered.connect(_on_cell_focused.bind(i))
	_reset_button.pressed.connect(_on_reset_pressed)
	_board.cell_changed.connect(_on_cell_changed)
	_board.turn_changed.connect(_on_turn_changed)
	_board.game_over.connect(_on_game_over)
	_board.reset()  # broadcast the initial state (turn_changed → "X")


## Handle the abstract input actions here in `_input` — ahead of the GUI's
## built-in ui_* focus navigation and a focused Button's own ui_accept — so the
## cursor_*/place/reset actions are the single source of grid control. Mouse and
## touch are untouched (they arrive as button presses, not these actions).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		_on_reset_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("place"):
		_on_cell_pressed(_selected)
		get_viewport().set_input_as_handled()
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


func _on_cell_focused(idx: int) -> void:
	_selected = idx  # keep the cursor in sync when focus moves (e.g. by mouse)


func _on_cell_pressed(idx: int) -> void:
	if _game_over:
		return
	_board.play(idx)


func _on_reset_pressed() -> void:
	_clear_board()
	_board.reset()


func _on_cell_changed(idx: int, mark: String) -> void:
	_cells[idx].text = mark


func _on_turn_changed(turn: String) -> void:
	_game_over = false
	_status.text = "%s's turn" % turn


func _on_game_over(outcome: String, line: PackedInt32Array) -> void:
	_game_over = true
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
