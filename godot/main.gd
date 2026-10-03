extends Control

## Thin view for the hot-seat tic-tac-toe game.
##
## Holds no rules. It forwards cell presses to the `TicTacToe` core node
## (`%Board`) and repaints when that node signals back — see
## docs/DESIGN_PRINCIPLES.md #2. The core emits tokens ("X"/"O"/"draw"); this
## view is what turns them into user-facing text and highlights.

const NAV_REPEAT_SECONDS := 0.2  # cursor auto-repeat cadence while a direction is held

var _cells: Array[Button] = []
var _selected: int = 0  # cell the keyboard/gamepad cursor is on
var _nav_cooldown: float = 0.0  # time left until the next held-direction move
var _on_reset: bool = false  # cursor is on the Reset button (below the grid)

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
	_reset_button.focus_entered.connect(_on_reset_focused)
	_board.cell_changed.connect(_on_cell_changed)
	_board.turn_changed.connect(_on_turn_changed)
	_board.game_over.connect(_on_game_over)
	_board.reset()  # broadcast the initial state (turn_changed → "X")
	_cells[_selected].grab_focus()  # a focused cell so the first `place` has a target


## `reset` and `place` are discrete, so they're handled per-event here (`place`
## activates only the focused cell and otherwise falls through to the focused
## control — see `_place_on_focused_cell`). `cursor_*` events are only swallowed
## here to pre-empt Godot's built-in ui_* focus navigation on these shared
## arrow/stick/D-pad bindings; the actual movement is polled and debounced in
## `_process`. Mouse and touch are untouched (they arrive as button presses).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		_on_reset_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("place"):
		_place_on_focused_cell()
	elif _is_cursor_event(event):
		get_viewport().set_input_as_handled()


## Apply held-direction movement on a fixed cadence. Polling the action state
## (rather than reacting to each event) is what tames the analog stick: a held
## stick/key/D-pad steps across the grid every NAV_REPEAT_SECONDS instead of
## either moving once or spamming a move per analog motion event.
func _process(delta: float) -> void:
	var dx: int = (
		int(Input.is_action_pressed("cursor_right")) - int(Input.is_action_pressed("cursor_left"))
	)
	var dy: int = (
		int(Input.is_action_pressed("cursor_down")) - int(Input.is_action_pressed("cursor_up"))
	)
	if dx == 0 and dy == 0:
		_nav_cooldown = 0.0  # released → the next press moves immediately
		return
	_nav_cooldown -= delta
	if _nav_cooldown <= 0.0:
		_move_selection(dx, dy)
		_nav_cooldown = NAV_REPEAT_SECONDS


func _is_cursor_event(event: InputEvent) -> bool:
	return (
		event.is_action("cursor_up")
		or event.is_action("cursor_down")
		or event.is_action("cursor_left")
		or event.is_action("cursor_right")
	)


## Move the cursor and focus the target (the focus ring is the visible cursor).
## The Reset button sits just below the bottom row: moving down from any
## bottom-row cell focuses it, moving up from it returns to the cell we left.
func _move_selection(dx: int, dy: int) -> void:
	if _on_reset:
		if dy < 0:  # up from Reset goes back to the grid cell we came from
			_cells[_selected].grab_focus()
		return  # left/right/further-down on Reset do nothing
	var col: int = clampi(_selected % 3 + dx, 0, 2)
	var row: int = _selected / 3 + dy
	if row > 2:  # down past the bottom row → the Reset button
		_reset_button.grab_focus()
		return
	_selected = clampi(row, 0, 2) * 3 + col
	_cells[_selected].grab_focus()


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
	# Keep the cursor in sync however focus moved (nav, mouse, code).
	_selected = idx
	_on_reset = false


func _on_reset_focused() -> void:
	_on_reset = true


func _on_cell_pressed(idx: int) -> void:
	# No game-over guard needed: the core rejects moves once the game is decided
	# (play returns false and emits nothing), so a late press is already a no-op.
	_board.play(idx)


func _on_reset_pressed() -> void:
	_clear_board()
	_board.reset()
	_cells[_selected].grab_focus()  # leave the Reset button, back to the grid


func _on_cell_changed(idx: int, mark: String) -> void:
	_cells[idx].text = mark


func _on_turn_changed(turn: String) -> void:
	_status.text = "%s's turn" % turn


func _on_game_over(outcome: String, line: PackedInt32Array) -> void:
	_reset_button.grab_focus()  # the only useful action now is to play again
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
