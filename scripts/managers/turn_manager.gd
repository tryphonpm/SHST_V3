## Migration notes:
##   • "turn" formerly meant one dice-roll cycle (old MAX_ROUNDS end condition — removed).
##   • "turn" now means a FULL LAP of the 34-cell pavement loop by a single player.
##   • A single dice roll is called a "step action".
##   • Game ends when every player satisfies PlayerData.has_finished_street().
##   • step_action_count is a purely informational stat — NEVER an end condition.
##   • Movement is modular: new_index = (old_index + steps) % LOOP_CELL_COUNT.
##     A lap is counted each time the player crosses from LOOP_END_INDEX (33) to
##     LOOP_START_INDEX (0).
extends Node

## Emitted when a player's step action (one dice-roll cycle) begins.
signal step_action_started(player_id: int)
## Emitted when a dice roll animation should begin.
signal dice_roll_started(player_id: int)
## Emitted after the dice roll is confirmed (animation done).
signal dice_rolled(player_id: int, value: int)
## Emitted when the player finishes moving and lands on a plain cell.
signal empty_cell_landed(player_id: int)
## Emitted when the player lands on a shop cell.
signal shop_landed(player_id: int, shop_id: StringName)
## Emitted when a player completes one full lap of the loop.
signal lap_completed(player_id: int, laps_completed: int)
## Emitted when a player has completed the required number of laps.
signal player_finished_street(player_id: int)
## Emitted exactly once when every player has finished the street.
signal game_ended(results: Array)

var current_player_index: int = 0
## Purely informational — NEVER use this as an end condition.
var step_action_count: int = 0

var _rng := RandomNumberGenerator.new()
var _is_rolling    := false
var _pending_roll_value := 0
var _finished_players: Array[int] = []
var _game_ended := false  # guard: game_ended fires exactly once

func _ready() -> void:
	# TODO: online multiplayer — host must seed RNG and broadcast the result
	# before clients animate.
	_rng.randomize()

# ---- Game flow ----

func start_game() -> void:
	current_player_index = 0
	step_action_count = 0
	_finished_players.clear()
	_game_ended = false
	_start_current_step_action()

func _start_current_step_action() -> void:
	_is_rolling = false
	step_action_started.emit(get_current_player().player_id)

# ---- Two-phase dice roll ----

## Phase 1: compute the result and notify that animation should begin.
## Returns the final value so the caller can pass it to DiceRoller.
func request_dice_roll() -> int:
	if _is_rolling:
		push_warning("TurnManager: roll already in progress")
		return _pending_roll_value
	_is_rolling = true
	_pending_roll_value = _rng.randi_range(GameConfig.DICE_MIN, GameConfig.DICE_MAX)
	dice_roll_started.emit(get_current_player().player_id)
	return _pending_roll_value

## Phase 2: called after the DiceRoller animation finishes.
func confirm_dice_roll(value: int) -> void:
	var player := get_current_player()
	dice_rolled.emit(player.player_id, value)
	_is_rolling = false

func is_roll_in_progress() -> bool:
	return _is_rolling

# ---- Movement ----

## Move the current player clockwise by `steps` cells around the 34-cell loop.
## Movement is modular: new_index = (old_index + steps) % LOOP_CELL_COUNT.
## A lap is counted each time the player crosses from LOOP_END_INDEX (33) to
## LOOP_START_INDEX (0).
##
## TODO: optional "exact finish" rule — require the player to land exactly on
##       LOOP_START_INDEX to complete a lap (currently any wrap counts).
func advance_current_player(steps: int) -> void:
	var player := get_current_player()
	var pos := player.board_position
	var crossed_start := false

	for _i in steps:
		if pos == GameConfig.LOOP_END_INDEX:
			# About to wrap: 33 → 0 = crossing the start line.
			crossed_start = true
		pos = (pos + 1) % GameConfig.LOOP_CELL_COUNT

	player.set_board_position(pos)

	if crossed_start:
		player.increment_laps()
		lap_completed.emit(player.player_id, player.laps_completed)
		if player.has_finished_street() and not _finished_players.has(player.player_id):
			# TODO: configurable "finished players keep playing for coins" mode.
			_finished_players.append(player.player_id)
			player_finished_street.emit(player.player_id)

## Resolve what happens on the cell the current player just landed on.
func resolve_landing(cell_index: int) -> void:
	var player := get_current_player()
	var shop_id := _get_shop_at(cell_index)
	if shop_id != &"":
		shop_landed.emit(player.player_id, shop_id)
	else:
		empty_cell_landed.emit(player.player_id)

## Called after every step action (movement + landing resolution) is complete.
## Advances to the next non-finished player, or ends the game if all are done.
func end_step_action() -> void:
	step_action_count += 1

	var total := GameManager.get_player_count()

	if _finished_players.size() >= total:
		_emit_game_ended_once()
		return

	# Rotate to the next player who still has laps to complete.
	for _i in total:
		current_player_index = (current_player_index + 1) % total
		var next_pid := GameManager.players[current_player_index].player_id
		if not _finished_players.has(next_pid):
			break

	# Re-check: might have looped through only finished players.
	var candidate_pid := GameManager.players[current_player_index].player_id
	if _finished_players.has(candidate_pid):
		_emit_game_ended_once()
		return

	_start_current_step_action()

func _emit_game_ended_once() -> void:
	if _game_ended:
		return
	_game_ended = true
	var results := GameManager.compute_final_ranking()
	game_ended.emit(results)

# ---- Queries ----

func get_current_player() -> PlayerData:
	return GameManager.players[current_player_index]

func get_step_action_count() -> int:
	return step_action_count

## Build the ordered list of cell indices the player traverses this step action.
## Wraps modularly around the loop (e.g. from cell 33, steps=2 → [0, 1]).
func compute_path(from: int, steps: int) -> Array[int]:
	var path: Array[int] = []
	var pos := from
	for _i in steps:
		pos = (pos + 1) % GameConfig.LOOP_CELL_COUNT
		path.append(pos)
	return path

# ---- Internals ----

func _get_shop_at(cell_index: int) -> StringName:
	for sid: StringName in GameConfig.SHOP_CELL_INDICES:
		if GameConfig.SHOP_CELL_INDICES[sid] == cell_index:
			return sid
	return &""
