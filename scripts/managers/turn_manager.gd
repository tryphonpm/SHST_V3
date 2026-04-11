extends Node

## Emitted when a player's turn begins.
signal turn_started(player_id: int)
## Emitted after the dice value is resolved.
signal dice_rolled(player_id: int, value: int)
## Emitted when the player finishes moving and lands on a plain cell.
signal empty_cell_landed(player_id: int)
## Emitted when the player lands on a shop cell.
signal shop_landed(player_id: int, shop_id: StringName)
## Emitted when every player has taken a turn this round.
signal all_turns_completed

var current_player_index: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

# ---- Turn flow ----

func start_game() -> void:
	current_player_index = 0
	_start_current_turn()

func _start_current_turn() -> void:
	turn_started.emit(get_current_player().player_id)

func roll_dice() -> int:
	var value := _rng.randi_range(GameConfig.DICE_MIN, GameConfig.DICE_MAX)
	var player := get_current_player()
	dice_rolled.emit(player.player_id, value)
	return value

## Move the current player forward by `steps` cells.
## Clamps to the last cell index.
## TODO: overshoot rule — bounce back by remainder (Game-of-Goose style).
func advance_current_player(steps: int) -> void:
	var player := get_current_player()
	var new_pos := mini(player.board_position + steps, GameConfig.STREET_CELL_COUNT - 1)
	player.set_board_position(new_pos)

## Resolve what happens on the cell the player just landed on.
func resolve_landing(cell_index: int) -> void:
	var player := get_current_player()
	var shop_id := _get_shop_at(cell_index)
	if shop_id != &"":
		shop_landed.emit(player.player_id, shop_id)
	else:
		empty_cell_landed.emit(player.player_id)

func end_turn() -> void:
	current_player_index += 1
	if current_player_index >= GameManager.get_player_count():
		current_player_index = 0
		all_turns_completed.emit()
	else:
		_start_current_turn()

# ---- Queries ----

func get_current_player() -> PlayerData:
	return GameManager.players[current_player_index]

## Build the list of cell indices the player will traverse (for animation).
func compute_path(from: int, steps: int) -> Array[int]:
	var path: Array[int] = []
	var pos := from
	for i in steps:
		pos += 1
		if pos >= GameConfig.STREET_CELL_COUNT:
			pos = GameConfig.STREET_CELL_COUNT - 1
			path.append(pos)
			break
		path.append(pos)
	return path

# ---- Internals ----

func _get_shop_at(cell_index: int) -> StringName:
	for sid in GameConfig.SHOP_CELL_INDICES:
		if GameConfig.SHOP_CELL_INDICES[sid] == cell_index:
			return sid
	return &""
