extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var street_board: StreetBoard = $StreetBoard
@onready var tokens_layer: Node2D = $PlayerTokensLayer
@onready var dice_button: Button = $UILayer/BottomBar/DiceButton
@onready var shopping_list_button: Button = $UILayer/BottomBar/ShoppingListButton
@onready var shopping_list_panel: PanelContainer = $UILayer/ShoppingListPanel
@onready var minigame_layer: CanvasLayer = $MinigameLayer

var _tokens: Dictionary = {}  # player_id → ColorRect (placeholder token)
var _is_busy := false

func _ready() -> void:
	# Assign shopping lists if not already done
	if GameManager.players.size() > 0 and GameManager.players[0].shopping_list.is_empty():
		GameManager.assign_shopping_lists()

	# Connect signals
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.dice_rolled.connect(_on_dice_rolled)
	TurnManager.empty_cell_landed.connect(_on_empty_cell_landed)
	TurnManager.shop_landed.connect(_on_shop_landed)
	TurnManager.all_turns_completed.connect(_on_all_turns_completed)
	GameManager.game_over.connect(_on_game_over)

	dice_button.pressed.connect(_on_dice_pressed)
	shopping_list_button.pressed.connect(_on_shopping_list_pressed)

	_spawn_tokens()
	_set_busy(true)

	# Wait a frame for the board to finish building
	await street_board.board_ready
	_set_busy(false)
	TurnManager.start_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("board_roll_dice") and not dice_button.disabled:
		_on_dice_pressed()
	elif event.is_action_pressed("board_toggle_list"):
		_on_shopping_list_pressed()

# ---- Tokens ----

func _spawn_tokens() -> void:
	# TODO: replace placeholder ColorRect visuals with real art once assets are available
	for pd in GameManager.players:
		var token := ColorRect.new()
		token.size = Vector2(28, 28)
		token.color = pd.color
		var cell := street_board.get_cell(pd.board_position)
		if cell:
			token.position = cell.get_world_anchor() - token.size * 0.5 + _token_offset(pd.player_id)
		tokens_layer.add_child(token)
		_tokens[pd.player_id] = token

func _token_offset(player_id: int) -> Vector2:
	# Stagger tokens vertically so they don't overlap on the same cell
	return Vector2(0, -20 + player_id * 14)

func _get_token(player_id: int) -> ColorRect:
	if _tokens.has(player_id):
		return _tokens[player_id]
	return null

# ---- Camera ----

func _focus_camera_on(player_id: int) -> void:
	var token := _get_token(player_id)
	if token:
		camera.position = token.position + token.size * 0.5

# ---- Busy flag ----

func _set_busy(busy: bool) -> void:
	_is_busy = busy
	dice_button.disabled = busy

# ---- Turn callbacks ----

func _on_turn_started(player_id: int) -> void:
	_set_busy(false)
	_focus_camera_on(player_id)
	dice_button.grab_focus()

func _on_dice_pressed() -> void:
	if _is_busy:
		return
	_set_busy(true)
	var roll := TurnManager.roll_dice()
	_animate_movement(roll)

func _on_dice_rolled(_player_id: int, _value: int) -> void:
	pass

func _animate_movement(steps: int) -> void:
	var player := TurnManager.get_current_player()
	var from_pos := player.board_position
	var path := TurnManager.compute_path(from_pos, steps)

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
		var cell := street_board.get_cell(cell_idx)
		if cell:
			var target := cell.get_world_anchor() - token.size * 0.5 + _token_offset(player.player_id)
			tween.tween_property(token, "position", target, GameConfig.CELL_HOP_DURATION)

	tween.finished.connect(func() -> void:
		_focus_camera_on(player.player_id)
		TurnManager.resolve_landing(player.board_position)
	)

func _on_empty_cell_landed(_player_id: int) -> void:
	TurnManager.end_turn()

func _on_shop_landed(_player_id: int, shop_id: StringName) -> void:
	MinigameManager.run_placeholder(shop_id, minigame_layer)

func _on_all_turns_completed() -> void:
	GameManager.advance_round()
	if GameManager.is_game_active:
		TurnManager.start_game()

func _on_game_over(winner: PlayerData) -> void:
	_set_busy(true)
	print("Game Over! Winner: %s with %d stars and %d coins" % [
		winner.display_name, winner.stars, winner.coins
	])

# ---- Shopping list ----

func _on_shopping_list_pressed() -> void:
	if shopping_list_panel.visible:
		shopping_list_panel.visible = false
	else:
		var player := TurnManager.get_current_player()
		if player:
			shopping_list_panel.show_for_player(player)
