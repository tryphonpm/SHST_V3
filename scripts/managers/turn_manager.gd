## Migration notes:
##   • "turn" formerly meant one dice-roll cycle (old MAX_ROUNDS end condition — removed).
##   • "turn" now means a FULL LAP of the pavement loop by a single player.
##   • A single dice roll is called a "step action".
##   • Game ends when every player satisfies PlayerData.has_finished_street().
##   • step_action_count is a purely informational stat — NEVER an end condition.
##   • Movement and lap detection are delegated to the injected BoardTopology.
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

var _topology: BoardTopology = null
var _rng := RandomNumberGenerator.new()
var _is_rolling    := false
var _pending_roll_value := 0
var _finished_players: Array[int] = []
var _game_ended := false  # guard: game_ended fires exactly once

func _ready() -> void:
	# TODO: online multiplayer — host must seed RNG and broadcast the result
	# before clients animate.
	_rng.randomize()

# ---- Topology injection ----

## Must be called before start_game() so movement and shop lookup work.
func set_topology(topology: BoardTopology) -> void:
	_topology = topology

func get_topology() -> BoardTopology:
	return _topology

# ---- Game flow ----

func start_game() -> void:
	assert(_topology != null, "TurnManager: set_topology() must be called before start_game()")
	current_player_index = 0
	step_action_count = 0
	_finished_players.clear()
	_game_ended = false
	_start_current_step_action()

func _start_current_step_action() -> void:
	_is_rolling = false
	step_action_started.emit(get_current_player().player_id)

# ---- Two-phase dice roll ----

func request_dice_roll() -> int:
	if _is_rolling:
		push_warning("TurnManager: roll already in progress")
		return _pending_roll_value
	_is_rolling = true
	_pending_roll_value = _rng.randi_range(GameConfig.DICE_MIN, GameConfig.DICE_MAX)
	dice_roll_started.emit(get_current_player().player_id)
	return _pending_roll_value

func confirm_dice_roll(value: int) -> void:
	var player := get_current_player()
	dice_rolled.emit(player.player_id, value)
	_is_rolling = false

func is_roll_in_progress() -> bool:
	return _is_rolling

# ---- Movement ----

## Move the current player forward by `steps` cells using the topology.
## A lap is counted each time the topology reports a lap boundary crossing.
##
## TODO: optional "exact finish" rule — require the player to land exactly on
##       LOOP_START_INDEX to complete a lap (currently any wrap counts).
func advance_current_player(steps: int) -> void:
	var player := get_current_player()
	var pos := player.board_position
	var crossed_lap := false

	for _i in steps:
		var next := _topology.next_cell(pos)
		if _topology.is_lap_boundary(pos, next):
			crossed_lap = true
		pos = next

	player.set_board_position(pos)

	if crossed_lap:
		player.increment_laps()
		lap_completed.emit(player.player_id, player.laps_completed)
		if player.has_finished_street() and not _finished_players.has(player.player_id):
			# TODO: configurable "finished players keep playing for coins" mode.
			_finished_players.append(player.player_id)
			player_finished_street.emit(player.player_id)

## Resolve what happens on the cell the current player just landed on.
func resolve_landing(cell_index: int) -> void:
	var player := get_current_player()
	var shop_id := _topology.get_shop_at(cell_index)
	if shop_id != &"":
		shop_landed.emit(player.player_id, shop_id)
	else:
		empty_cell_landed.emit(player.player_id)

## Called after every step action (movement + landing resolution) is complete.
func end_step_action() -> void:
	step_action_count += 1

	var total := GameManager.get_player_count()

	if _finished_players.size() >= total:
		_emit_game_ended_once()
		return

	for _i in total:
		current_player_index = (current_player_index + 1) % total
		var next_pid := GameManager.players[current_player_index].player_id
		if not _finished_players.has(next_pid):
			break

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
func compute_path(from: int, steps: int) -> Array[int]:
	return _topology.compute_path(from, steps)
