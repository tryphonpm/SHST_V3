extends Node2D

@onready var camera:               Camera2D       = $Camera2D
@onready var loop_board:           LoopBoard      = $LoopBoard
@onready var tokens_layer:         Node2D         = $PlayerTokensLayer
@onready var dice_button:          Button         = $UILayer/BottomBar/DiceButton
@onready var shopping_list_button: Button         = $UILayer/BottomBar/ShoppingListButton
@onready var shopping_list_panel:  PanelContainer = $UILayer/ShoppingListPanel
@onready var dice_roller:          Control        = $UILayer/DiceRoller
@onready var minigame_layer:       CanvasLayer    = $MinigameLayer

var _tokens:        Dictionary = {}   # player_id → ColorRect
var _finish_badges: Dictionary = {}   # player_id → Label (FINISHED overlay)
var _is_busy    := false
var _pending_roll_value := 0
var _safety_timer: SceneTreeTimer = null

## Session RNG: randomised once per game, passed to LoopBoard.build().
var _session_rng := RandomNumberGenerator.new()

func _ready() -> void:
	TurnManager.step_action_started.connect(_on_step_action_started)
	TurnManager.dice_rolled.connect(_on_dice_rolled)
	TurnManager.empty_cell_landed.connect(_on_empty_cell_landed)
	TurnManager.shop_landed.connect(_on_shop_landed)
	TurnManager.lap_completed.connect(_on_lap_completed)
	TurnManager.player_finished_street.connect(_on_player_finished_street)
	TurnManager.game_ended.connect(_on_game_ended)
	MinigameManager.minigame_finished.connect(_on_minigame_finished)

	dice_button.pressed.connect(_on_dice_pressed)
	shopping_list_button.pressed.connect(_on_shopping_list_pressed)
	dice_roller.roll_finished.connect(_on_dice_roll_finished)

	if GameManager.players.size() < GameConfig.MIN_PLAYERS:
		push_warning("BoardGame: not enough players (%d), adding placeholder AI" % GameManager.players.size())
		_fill_placeholder_players()

	# ── Board topology (injected into both LoopBoard and TurnManager) ──
	# TODO: will support Paris-district topology and graph-based routing —
	# swap this line for a different BoardTopology subclass.
	var topology := RectangularLoopTopology.new()

	_session_rng.randomize()
	loop_board.build(topology, _session_rng)
	TurnManager.set_topology(topology)
	_setup_camera(topology)

	GameManager.start_game()
	GameManager.assign_shopping_lists()

	_spawn_tokens()
	TurnManager.start_game()

func _fill_placeholder_players() -> void:
	var ids := AvatarCatalog.get_avatar_ids()
	var idx := 0
	while GameManager.players.size() < GameConfig.MIN_PLAYERS:
		var info := AvatarCatalog.get_avatar(ids[idx % ids.size()])
		var pd := GameManager.register_player(info["display_name"] + " (AI)", info["color"], true)
		if pd:
			pd.set_avatar(ids[idx % ids.size()])
		idx += 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("board_roll_dice") and not _is_busy:
		_on_dice_pressed()
	elif event.is_action_pressed("board_toggle_list"):
		_on_shopping_list_pressed()

# ---- Camera ----

func _setup_camera(topology: BoardTopology) -> void:
	var pad  := GameConfig.CAMERA_LOOP_PADDING
	var rect := topology.get_bounding_rect()

	camera.limit_left   = int(rect.position.x - pad)
	camera.limit_top    = int(rect.position.y - pad)
	camera.limit_right  = int(rect.end.x      + pad)
	camera.limit_bottom = int(rect.end.y      + pad)

	# Zoom out to frame the whole board on smaller viewports.
	var vp  := get_viewport_rect().size
	var bw  := rect.size.x + 2.0 * pad
	var bh  := rect.size.y + 2.0 * pad
	var fit := minf(vp.x / bw, vp.y / bh)
	if fit < 1.0:
		camera.zoom = Vector2(fit, fit)

	# Start the camera centred on the board.
	camera.position = rect.position + rect.size * 0.5

func _focus_camera_on(player_id: int) -> void:
	var token := _get_token(player_id)
	if token:
		camera.position = token.position + token.size * 0.5

# ---- Tokens ----

func _spawn_tokens() -> void:
	# TODO: replace placeholder ColorRect visuals with real art once assets are available
	for pd in GameManager.players:
		var token := ColorRect.new()
		token.size  = Vector2(28, 28)
		token.color = pd.color
		var cell := loop_board.get_cell(pd.board_position)
		if cell:
			token.position = cell.get_world_anchor() - token.size * 0.5 + _token_offset(pd.player_id)
		tokens_layer.add_child(token)
		_tokens[pd.player_id] = token

func _token_offset(player_id: int) -> Vector2:
	return Vector2(0, -20 + player_id * 14)

func _get_token(player_id: int) -> ColorRect:
	return _tokens.get(player_id, null)

# ---- Busy flag ----

func _set_busy(busy: bool) -> void:
	_is_busy = busy
	dice_button.disabled = busy

# ---- Dice rolling (two-phase) ----

func _on_dice_pressed() -> void:
	if _is_busy or dice_roller.is_rolling():
		return
	_set_busy(true)

	if shopping_list_panel.visible:
		shopping_list_panel.visible = false

	_pending_roll_value = TurnManager.request_dice_roll()
	dice_roller.visible    = true
	dice_roller.modulate.a = 1.0
	dice_roller.roll(_pending_roll_value)

	var safety_duration: float = (
		GameConfig.DICE_ROLL_SHUFFLE_DURATION
		+ GameConfig.DICE_RESULT_HOLD_DURATION
		+ 0.5
	)
	_safety_timer = get_tree().create_timer(safety_duration)
	_safety_timer.timeout.connect(_on_safety_timeout, CONNECT_ONE_SHOT)

func _on_dice_roll_finished(value: int) -> void:
	_safety_timer = null
	TurnManager.confirm_dice_roll(value)

	var fade := create_tween()
	fade.tween_property(dice_roller, "modulate:a", 0.0, 0.2)
	fade.tween_callback(func() -> void:
		dice_roller.visible    = false
		dice_roller.modulate.a = 1.0
		_animate_movement(value)
	)

func _on_safety_timeout() -> void:
	if dice_roller.is_rolling() or TurnManager.is_roll_in_progress():
		push_warning("BoardGame: DiceRoller safety timer expired — force-confirming roll")
		_on_dice_roll_finished(_pending_roll_value)

func _on_dice_rolled(_player_id: int, _value: int) -> void:
	pass

# ---- Step-action callbacks ----

func _on_step_action_started(player_id: int) -> void:
	_set_busy(false)
	_focus_camera_on(player_id)
	dice_button.grab_focus()

# ---- Movement ----

func _animate_movement(steps: int) -> void:
	var player   := TurnManager.get_current_player()
	var from_pos := player.board_position
	var path     := TurnManager.compute_path(from_pos, steps)

	if path.is_empty():
		TurnManager.advance_current_player(steps)
		TurnManager.resolve_landing(player.board_position)
		return

	TurnManager.advance_current_player(steps)

	var token := _get_token(player.player_id)
	if token == null:
		TurnManager.resolve_landing(player.board_position)
		return

	var tween := create_tween()
	for cell_idx in path:
		var cell := loop_board.get_cell(cell_idx)
		if cell:
			var target := cell.get_world_anchor() - token.size * 0.5 + _token_offset(player.player_id)
			tween.tween_property(token, "position", target, GameConfig.CELL_HOP_DURATION)

	tween.finished.connect(func() -> void:
		_focus_camera_on(player.player_id)
		TurnManager.resolve_landing(player.board_position)
	)

func _on_empty_cell_landed(_player_id: int) -> void:
	TurnManager.end_step_action()

func _on_shop_landed(_player_id: int, shop_id: StringName) -> void:
	MinigameManager.run_placeholder(shop_id, minigame_layer)

# ---- Shop bounce tween (purchase feedback) ----

func _on_minigame_finished(shop_id: StringName) -> void:
	var topo := TurnManager.get_topology()
	if topo == null:
		return
	var indices := topo.get_shop_cell_indices()
	var cell_idx: int = indices.get(shop_id, -1)
	if cell_idx == -1:
		return
	var marker := loop_board.get_shop_marker_at_cell(cell_idx)
	if marker == null:
		return
	var tween := create_tween()
	tween.tween_property(marker, "scale", Vector2(1.15, 1.15), 0.12)
	tween.tween_property(marker, "scale", Vector2(1.0,  1.0),  0.13)

# ---- Lap / finish events ----

func _on_lap_completed(player_id: int, laps_done: int) -> void:
	var token := _get_token(player_id)
	if token == null:
		return
	var tween := create_tween()
	tween.tween_property(token, "scale",    Vector2(1.6, 1.6), 0.12)
	tween.tween_property(token, "modulate", Color.WHITE * 2.0, 0.08)
	tween.tween_property(token, "scale",    Vector2(1.0, 1.0), 0.12)
	tween.tween_property(token, "modulate", Color.WHITE,       0.08)
	print("Player %d completed lap %d!" % [player_id, laps_done])

func _on_player_finished_street(player_id: int) -> void:
	var token := _get_token(player_id)
	if token:
		token.modulate.a = 0.45

	if _finish_badges.has(player_id):
		return
	var badge := Label.new()
	badge.text = "FINISHED"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color.GOLD)
	if token:
		badge.position = token.position + Vector2(-10, -20)
	tokens_layer.add_child(badge)
	_finish_badges[player_id] = badge

func _on_game_ended(results: Array) -> void:
	_set_busy(true)
	var panel_scene := load("res://scenes/ui/GameOverPanel.tscn") as PackedScene
	if panel_scene == null:
		push_error("BoardGame: cannot load GameOverPanel.tscn")
		return
	var panel := panel_scene.instantiate()
	if panel.has_method("setup"):
		panel.setup(results)
	add_child(panel)

# ---- Shopping list ----

func _on_shopping_list_pressed() -> void:
	if shopping_list_panel.visible:
		shopping_list_panel.visible = false
	else:
		var player := TurnManager.get_current_player()
		if player:
			shopping_list_panel.show_for_player(player)
