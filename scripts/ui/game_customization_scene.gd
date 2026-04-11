extends Control

signal avatar_selected(avatar_id: String)

@onready var avatar_container: HBoxContainer = $MarginContainer/VBox/AvatarContainer
@onready var btn_start: Button = $MarginContainer/VBox/ButtonRow/BtnStart
@onready var btn_back: Button  = $MarginContainer/VBox/ButtonRow/BtnBack

var _selected_id: String = ""
var _cards: Array[Button] = []

func _ready() -> void:
	btn_start.disabled = true
	btn_start.pressed.connect(_on_start)
	btn_back.pressed.connect(_on_back)

	_build_avatar_cards()

	if _cards.size() > 0:
		_cards[0].grab_focus()

func _build_avatar_cards() -> void:
	for child in avatar_container.get_children():
		child.queue_free()
	_cards.clear()

	for avatar in AvatarCatalog.AVATARS:
		var card := _create_card(avatar)
		avatar_container.add_child(card)
		_cards.append(card)

func _create_card(avatar: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(200, 260)
	card.focus_mode = Control.FOCUS_ALL

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Portrait placeholder
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(avatar["portrait_path"]):
		portrait.texture = load(avatar["portrait_path"])
	else:
		var img := Image.create(120, 120, false, Image.FORMAT_RGBA8)
		img.fill(avatar["color"])
		portrait.texture = ImageTexture.create_from_image(img)
	vbox.add_child(portrait)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = avatar["display_name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Color swatch
	var swatch := ColorRect.new()
	swatch.color = avatar["color"]
	swatch.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(swatch)

	card.add_child(vbox)

	var aid: String = avatar["id"]
	card.pressed.connect(_on_card_pressed.bind(aid))
	card.focus_entered.connect(func() -> void: AudioManager.play_sfx("menu_move"))
	return card

func _on_card_pressed(avatar_id: String) -> void:
	_selected_id = avatar_id
	btn_start.disabled = false
	AudioManager.play_sfx("menu_confirm")

	# Visual feedback: highlight selected card
	for i in _cards.size():
		var is_sel: bool = (AvatarCatalog.AVATARS[i]["id"] == avatar_id)
		_cards[i].modulate = Color.WHITE if is_sel else Color(0.5, 0.5, 0.5, 1.0)

	avatar_selected.emit(avatar_id)

func _on_start() -> void:
	if _selected_id.is_empty():
		return
	GameManager.clear_players()
	GameManager.set_local_player_avatar(_selected_id)

	# Fill remaining slots with AI for testing
	var ai_index := 0
	while GameManager.get_player_count() < GameConfig.MIN_PLAYERS:
		var ids := AvatarCatalog.get_avatar_ids()
		var ai_avatar := ids[ai_index % ids.size()]
		if ai_avatar == _selected_id:
			ai_index += 1
			ai_avatar = ids[ai_index % ids.size()]
		var info := AvatarCatalog.get_avatar(ai_avatar)
		var pd := GameManager.register_player(info["display_name"] + " (AI)", info["color"], true)
		if pd:
			pd.set_avatar(ai_avatar)
		ai_index += 1

	AudioManager.play_sfx("menu_confirm")
	SceneRouter.goto(SceneRouter.Screen.GAME)

func _on_back() -> void:
	SceneRouter.goto(SceneRouter.Screen.MAIN_MENU)
