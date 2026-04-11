extends CanvasLayer

@onready var step_action_label: Label = $MarginContainer/VBox/StepActionLabel
@onready var player_panels: HBoxContainer = $MarginContainer/VBox/PlayerPanels
@onready var dice_result_label: Label = $MarginContainer/VBox/DiceResultLabel

var _panel_map: Dictionary = {}  # player_id → Control

func _ready() -> void:
	GameManager.game_started.connect(_on_game_started)
	GameManager.player_data_changed.connect(_on_player_data_changed)
	TurnManager.step_action_started.connect(_on_step_action_started)
	TurnManager.dice_roll_started.connect(_on_dice_roll_started)
	TurnManager.dice_rolled.connect(_on_dice_rolled)
	TurnManager.lap_completed.connect(_on_lap_completed)

	dice_result_label.text = ""

func _on_game_started() -> void:
	_build_panels()
	_refresh_step_label()

func _build_panels() -> void:
	for child in player_panels.get_children():
		child.queue_free()
	_panel_map.clear()

	for pd in GameManager.players:
		var panel := _create_player_panel(pd)
		player_panels.add_child(panel)
		_panel_map[pd.player_id] = panel

func _create_player_panel(pd: PlayerData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 0)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = pd.display_name
	name_label.add_theme_color_override("font_color", pd.color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var coins_label := Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.text = "Coins: %d" % pd.coins
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var lap_label := Label.new()
	lap_label.name = "LapLabel"
	lap_label.text = "Lap %d / %d" % [pd.laps_completed, GameConfig.required_laps]
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var pos_label := Label.new()
	pos_label.name = "PositionLabel"
	# Display 1-based cell number to match the board visual (cells 1..34).
	pos_label.text = "Cell %d / %d" % [pd.board_position + 1, GameConfig.LOOP_CELL_COUNT]
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(name_label)
	vbox.add_child(coins_label)
	vbox.add_child(lap_label)
	vbox.add_child(pos_label)
	panel.add_child(vbox)
	return panel

func _refresh_step_label() -> void:
	step_action_label.text = "Step %d" % TurnManager.get_step_action_count()

func _on_step_action_started(player_id: int) -> void:
	_refresh_step_label()
	dice_result_label.text = ""
	var player := GameManager.get_player(player_id)
	if player:
		step_action_label.text += "  —  %s's turn" % player.display_name

func _on_dice_roll_started(_player_id: int) -> void:
	dice_result_label.text = "Rolling..."

func _on_dice_rolled(_player_id: int, value: int) -> void:
	dice_result_label.text = "Rolled: %d" % value

func _on_lap_completed(player_id: int, _laps_done: int) -> void:
	_refresh_player_panel(player_id)

func _refresh_player_panel(player_id: int) -> void:
	if not _panel_map.has(player_id):
		return
	var player := GameManager.get_player(player_id)
	if player == null:
		return
	var panel: PanelContainer = _panel_map[player_id]
	var vbox := panel.get_node("VBox")
	vbox.get_node("CoinsLabel").text = "Coins: %d" % player.coins
	vbox.get_node("LapLabel").text      = "Lap %d / %d" % [player.laps_completed, GameConfig.required_laps]
	vbox.get_node("PositionLabel").text = "Cell %d / %d" % [player.board_position + 1, GameConfig.LOOP_CELL_COUNT]

func _on_player_data_changed(player: PlayerData, _property_name: String) -> void:
	_refresh_player_panel(player.player_id)
