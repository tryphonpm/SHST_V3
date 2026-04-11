extends CanvasLayer

@onready var turn_label: Label = $MarginContainer/VBox/TurnLabel
@onready var player_panels: HBoxContainer = $MarginContainer/VBox/PlayerPanels

var _panel_map: Dictionary = {}  # player_id → Control

func _ready() -> void:
	GameManager.game_started.connect(_on_game_started)
	GameManager.player_data_changed.connect(_on_player_data_changed)
	TurnManager.turn_started.connect(_on_turn_started)

func _on_game_started() -> void:
	_build_panels()
	_refresh_turn_label()

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

	var stars_label := Label.new()
	stars_label.name = "StarsLabel"
	stars_label.text = "Stars: %d" % pd.stars
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(name_label)
	vbox.add_child(coins_label)
	vbox.add_child(stars_label)
	panel.add_child(vbox)
	return panel

func _refresh_turn_label() -> void:
	turn_label.text = "Round %d / %d" % [GameManager.current_round, GameConfig.current_rounds]

func _on_turn_started(player_id: int) -> void:
	_refresh_turn_label()
	var player := GameManager.get_player(player_id)
	if player:
		turn_label.text += "  —  %s's turn" % player.display_name

func _on_player_data_changed(player: PlayerData, _property_name: String) -> void:
	if not _panel_map.has(player.player_id):
		return
	var panel: PanelContainer = _panel_map[player.player_id]
	var vbox := panel.get_node("VBox")
	vbox.get_node("CoinsLabel").text = "Coins: %d" % player.coins
	vbox.get_node("StarsLabel").text = "Stars: %d" % player.stars
