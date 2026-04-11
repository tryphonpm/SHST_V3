extends CanvasLayer

@onready var rows_container: VBoxContainer = $PanelContainer/MarginContainer/VBox/RowsContainer
@onready var btn_main_menu: Button = $PanelContainer/MarginContainer/VBox/ButtonRow/BtnMainMenu
@onready var btn_quit: Button = $PanelContainer/MarginContainer/VBox/ButtonRow/BtnQuit

func _ready() -> void:
	btn_main_menu.pressed.connect(_on_main_menu)
	btn_quit.pressed.connect(_on_quit)
	btn_main_menu.grab_focus()

## Called by board_game.gd with the sorted ranking array from GameManager.
func setup(results: Array) -> void:
	for child in rows_container.get_children():
		child.queue_free()

	for i in results.size():
		var pd: PlayerData = results[i]
		var row := _create_row(i + 1, pd)
		rows_container.add_child(row)

func _create_row(rank: int, pd: PlayerData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_override_constants = {"separation": 16}

	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.custom_minimum_size = Vector2(40, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var name_lbl := Label.new()
	name_lbl.text = pd.display_name
	name_lbl.add_theme_color_override("font_color", pd.color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var items_lbl := Label.new()
	items_lbl.text = "Items: %d" % pd.collected_items.size()
	items_lbl.custom_minimum_size = Vector2(90, 0)
	items_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var laps_lbl := Label.new()
	laps_lbl.text = "Laps: %d" % pd.laps_completed
	laps_lbl.custom_minimum_size = Vector2(70, 0)
	laps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var coins_lbl := Label.new()
	coins_lbl.text = "Coins: %d" % pd.coins
	coins_lbl.custom_minimum_size = Vector2(80, 0)
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	row.add_child(rank_lbl)
	row.add_child(name_lbl)
	row.add_child(items_lbl)
	row.add_child(laps_lbl)
	row.add_child(coins_lbl)
	return row

func _on_main_menu() -> void:
	SceneRouter.goto(SceneRouter.Screen.MAIN_MENU)

func _on_quit() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu()
