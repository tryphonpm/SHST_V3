## Migration notes:
##   • "turn" formerly meant one dice-roll cycle (old MAX_ROUNDS end condition — removed).
##   • "turn" now means a FULL LAP of the pavement loop by a single player.
##   • A single dice roll is called a "step action".
##   • Game ends when every player satisfies PlayerData.has_finished_street().
##   • step_action_count is a purely informational stat — NEVER an end condition.
##   • Movement and lap detection are delegated to the BoardGraph.
##   • When the player lands ON an Intersection during movement, movement
##     pauses until the player (or timeout) picks a direction via
##     choose_intersection_path(). The remaining steps then resume.
extends Node

signal step_action_started(player_id: int)
signal dice_roll_started(player_id: int)
signal dice_rolled(player_id: int, value: int)
signal empty_cell_landed(player_id: int)
signal shop_landed(player_id: int, shop_id: StringName)
signal lap_completed(player_id: int, laps_completed: int)
signal player_finished_street(player_id: int)
signal game_ended(results: Array)
## Emitted when movement pauses at an Intersection requiring a player choice.
signal intersection_reached(player_id: int, intersection: Intersection)
## Emitted after the player (or timeout) resolves the intersection choice.
signal intersection_resolved(player_id: int, chosen_index: int)

var current_player_index: int = 0
var step_action_count: int = 0

var _graph: BoardGraph = null
var _rng := RandomNumberGenerator.new()
var _is_rolling    := false
var _pending_roll_value := 0
var _finished_players: Array[int] = []
var _game_ended := false

# ── Intersection pause state ──
var _remaining_steps: int = 0
var _awaiting_intersection := false

func _ready() -> void:
	_rng.randomize()

# ---- Graph injection ----

func set_graph(graph: BoardGraph) -> void:
	_graph = graph

func get_graph() -> BoardGraph:
	return _graph

# ---- Game flow ----

func start_game() -> void:
	assert(
		_graph != null,
		"TurnManager: set_graph() must be called before start_game()"
	)
	current_player_index = 0
	step_action_count = 0
	_finished_players.clear()
	_game_ended = false
	_remaining_steps = 0
	_awaiting_intersection = false
	_start_current_step_action()

func _start_current_step_action() -> void:
	_is_rolling = false
	_awaiting_intersection = false
	_remaining_steps = 0
	step_action_started.emit(get_current_player().player_id)

# ---- Two-phase dice roll ----

func request_dice_roll() -> int:
	if _is_rolling:
		push_warning("TurnManager: roll already in progress")
		return _pending_roll_value
	_is_rolling = true
	_pending_roll_value = _rng.randi_range(
		GameConfig.DICE_MIN, GameConfig.DICE_MAX
	)
	dice_roll_started.emit(get_current_player().player_id)
	return _pending_roll_value

func confirm_dice_roll(value: int) -> void:
	var player := get_current_player()
	dice_rolled.emit(player.player_id, value)
	_is_rolling = false

func is_roll_in_progress() -> bool:
	return _is_rolling

# ---- Movement (graph-based, intersection-aware) ----

## Move the current player forward by `steps` edges in the BoardGraph.
## If the player reaches an Intersection mid-walk, movement pauses and
## intersection_reached is emitted. Call choose_intersection_path() to
## set the direction and resume with the remaining steps.
##
## TODO: optional "exact finish" rule — require the player to land
##       exactly on start_node_id to complete a lap.
func advance_current_player(steps: int) -> void:
	var player := get_current_player()
	var pos_id := player.board_node_id
	var crossed_lap := false

	var walked := 0
	for i in steps:
		var next_id := _graph.get_default_next(pos_id)
		if _graph.is_start_node(next_id) \
				and not _graph.is_start_node(pos_id):
			crossed_lap = true
		pos_id = next_id
		walked += 1

		# Pause when landing ON an intersection with remaining steps.
		var remaining := steps - walked
		if remaining > 0 and _graph.is_intersection(pos_id):
			player.set_board_node(pos_id)
			_handle_lap_crossing(player, crossed_lap)
			_pause_at_intersection(pos_id, remaining)
			return

	player.set_board_node(pos_id)
	_handle_lap_crossing(player, crossed_lap)

## Called by the board UI (or timeout) after the player picks a direction
## at an Intersection. `choice_index` maps to
## Intersection.choice_destinations / next_nodes.
func choose_intersection_path(choice_index: int) -> void:
	if not _awaiting_intersection:
		push_warning("TurnManager: not awaiting an intersection choice")
		return
	_awaiting_intersection = false

	var player := get_current_player()
	var node := _graph.get_node_by_id(player.board_node_id)
	if node == null or not node is Intersection:
		push_error(
			"TurnManager: player not on an Intersection node"
		)
		return

	var inter := node as Intersection
	var clamped := clampi(choice_index, 0, inter.choice_count - 1)
	var chosen_dest: StringName = inter.choice_destinations[clamped]

	intersection_resolved.emit(player.player_id, clamped)

	# Step onto the chosen destination (counts as 1 step).
	var crossed_lap := false
	if _graph.is_start_node(chosen_dest) \
			and not _graph.is_start_node(player.board_node_id):
		crossed_lap = true
	player.set_board_node(chosen_dest)
	var steps_left := _remaining_steps - 1
	_remaining_steps = 0

	# Continue walking the remaining steps (may hit another intersection).
	if steps_left > 0:
		_continue_movement(player, steps_left, crossed_lap)
	else:
		_handle_lap_crossing(player, crossed_lap)

## True while the game is waiting for a player to pick at an intersection.
func is_awaiting_intersection() -> bool:
	return _awaiting_intersection

## Steps remaining after the current intersection choice.
func get_remaining_steps() -> int:
	return _remaining_steps

# ── Private movement helpers ──

func _pause_at_intersection(
	node_id: StringName, remaining: int
) -> void:
	_remaining_steps = remaining
	_awaiting_intersection = true
	var node := _graph.get_node_by_id(node_id) as Intersection
	intersection_reached.emit(
		get_current_player().player_id, node
	)

func _continue_movement(
	player: PlayerData, steps: int, crossed_lap_so_far: bool
) -> void:
	var pos_id := player.board_node_id
	var crossed_lap := crossed_lap_so_far

	var walked := 0
	for i in steps:
		var next_id := _graph.get_default_next(pos_id)
		if _graph.is_start_node(next_id) \
				and not _graph.is_start_node(pos_id):
			crossed_lap = true
		pos_id = next_id
		walked += 1

		var remaining := steps - walked
		if remaining > 0 and _graph.is_intersection(pos_id):
			player.set_board_node(pos_id)
			_handle_lap_crossing(player, crossed_lap)
			_pause_at_intersection(pos_id, remaining)
			return

	player.set_board_node(pos_id)
	_handle_lap_crossing(player, crossed_lap)

func _handle_lap_crossing(
	player: PlayerData, crossed: bool
) -> void:
	if not crossed:
		return
	player.increment_laps()
	lap_completed.emit(player.player_id, player.laps_completed)
	if player.has_finished_street() \
			and not _finished_players.has(player.player_id):
		_finished_players.append(player.player_id)
		player_finished_street.emit(player.player_id)

## Resolve what happens on the node the current player just landed on.
func resolve_landing(node_id: StringName) -> void:
	var player := get_current_player()
	var shop_id := _graph.get_shop_at(node_id)
	if shop_id != &"":
		shop_landed.emit(player.player_id, shop_id)
	else:
		empty_cell_landed.emit(player.player_id)

func end_step_action() -> void:
	step_action_count += 1

	var total := GameManager.get_player_count()

	if _finished_players.size() >= total:
		_emit_game_ended_once()
		return

	for _i in total:
		current_player_index = (current_player_index + 1) % total
		var pid := GameManager.players[current_player_index].player_id
		if not _finished_players.has(pid):
			break

	var cand := GameManager.players[current_player_index].player_id
	if _finished_players.has(cand):
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

## Build the ordered list of node IDs the player traverses this
## step action. Stops early at the first Intersection node encountered,
## since the path beyond it depends on the player's choice.
func compute_path(
	from_id: StringName, steps: int
) -> Array[StringName]:
	var path: Array[StringName] = []
	var pos := from_id
	for _i in steps:
		pos = _graph.get_default_next(pos)
		path.append(pos)
		if _graph.is_intersection(pos):
			break
	return path
