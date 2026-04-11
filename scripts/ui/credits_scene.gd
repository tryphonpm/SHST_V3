extends Control

@onready var credits_label: RichTextLabel = $MarginContainer/CreditsLabel

var _scroll_offset: float = 0.0
var _auto_scroll := true

func _ready() -> void:
	credits_label.bbcode_enabled = true
	credits_label.text = _build_credits_text()
	credits_label.scroll_following = false
	_scroll_offset = 0.0

func _process(delta: float) -> void:
	if not _auto_scroll:
		return
	_scroll_offset += GameConfig.CREDITS_SCROLL_SPEED * delta
	credits_label.get_v_scroll_bar().value = _scroll_offset

	if _scroll_offset >= credits_label.get_v_scroll_bar().max_value:
		_auto_scroll = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		SceneRouter.goto(SceneRouter.Screen.MAIN_MENU)

func _build_credits_text() -> String:
	return (
		"[center][b][font_size=32]SHITTY STREET v3[/font_size][/b]\n\n"
		+ "[font_size=18]A Mario-Party-inspired party game[/font_size]\n\n"
		+ "━━━━━━━━━━━━━━━━━━━━\n\n"
		+ "[b]Game Design & Programming[/b]\n"
		+ "Your Name Here\n\n"
		+ "[b]Art & Animation[/b]\n"
		+ "Your Name Here\n\n"
		+ "[b]Music & Sound[/b]\n"
		+ "Your Name Here\n\n"
		+ "[b]Quality Assurance[/b]\n"
		+ "Your Name Here\n\n"
		+ "━━━━━━━━━━━━━━━━━━━━\n\n"
		+ "[b]Engine[/b]\n"
		+ "Made with [b]Godot 4[/b]\n"
		+ "https://godotengine.org\n\n"
		+ "[b]Third-Party Assets[/b]\n"
		+ "Placeholder art — replace with licensed assets\n\n"
		+ "━━━━━━━━━━━━━━━━━━━━\n\n"
		+ "[b]Special Thanks[/b]\n"
		+ "The Godot community\n"
		+ "Playtesters & friends\n\n"
		+ "Version %s\n\n"
		% GameConfig.VERSION
		+ "[i]Press any key to return to menu[/i][/center]"
	)
