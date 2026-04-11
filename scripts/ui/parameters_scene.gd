extends Control

const SETTINGS_PATH := "user://settings.cfg"

@onready var slider_master: HSlider   = $MarginContainer/VBox/MasterRow/Slider
@onready var slider_bgm: HSlider      = $MarginContainer/VBox/BGMRow/Slider
@onready var slider_sfx: HSlider      = $MarginContainer/VBox/SFXRow/Slider
@onready var chk_fullscreen: CheckBox = $MarginContainer/VBox/FullscreenRow/CheckBox
@onready var opt_language: OptionButton = $MarginContainer/VBox/LanguageRow/OptionButton
@onready var slider_rounds: HSlider   = $MarginContainer/VBox/RoundsRow/Slider
@onready var lbl_rounds: Label        = $MarginContainer/VBox/RoundsRow/ValueLabel
@onready var slider_shopping: HSlider = $MarginContainer/VBox/ShoppingRow/Slider
@onready var lbl_shopping: Label      = $MarginContainer/VBox/ShoppingRow/ValueLabel
@onready var btn_apply: Button        = $MarginContainer/VBox/ButtonRow/BtnApply
@onready var btn_back: Button         = $MarginContainer/VBox/ButtonRow/BtnBack

func _ready() -> void:
	_setup_language_dropdown()
	_load_settings()

	slider_rounds.min_value = GameConfig.MIN_ROUNDS
	slider_rounds.max_value = GameConfig.MAX_ROUNDS_CAP
	slider_rounds.step = 1
	slider_rounds.value = GameConfig.current_rounds
	lbl_rounds.text = str(int(slider_rounds.value))

	slider_master.min_value = 0; slider_master.max_value = 100; slider_master.step = 1
	slider_bgm.min_value = 0;   slider_bgm.max_value = 100;   slider_bgm.step = 1
	slider_sfx.min_value = 0;   slider_sfx.max_value = 100;   slider_sfx.step = 1

	slider_shopping.min_value = GameConfig.SHOPPING_LIST_MIN_SIZE
	slider_shopping.max_value = GameConfig.SHOPPING_LIST_MAX_SIZE
	slider_shopping.step = 1
	slider_shopping.value = GameConfig.shopping_list_size
	lbl_shopping.text = str(int(slider_shopping.value))

	slider_rounds.value_changed.connect(func(v: float) -> void: lbl_rounds.text = str(int(v)))
	slider_shopping.value_changed.connect(func(v: float) -> void: lbl_shopping.text = str(int(v)))

	btn_apply.pressed.connect(_apply)
	btn_back.pressed.connect(_go_back)

	slider_master.grab_focus()

func _setup_language_dropdown() -> void:
	opt_language.clear()
	opt_language.add_item("English", 0)
	opt_language.add_item("Français", 1)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		slider_master.value = 100; slider_bgm.value = 100; slider_sfx.value = 100
		chk_fullscreen.button_pressed = false
		opt_language.selected = 0
		return

	slider_master.value = cfg.get_value("audio", "master_volume", 100.0)
	slider_bgm.value    = cfg.get_value("audio", "bgm_volume", 100.0)
	slider_sfx.value    = cfg.get_value("audio", "sfx_volume", 100.0)
	chk_fullscreen.button_pressed = cfg.get_value("video", "fullscreen", false)
	opt_language.selected = cfg.get_value("locale", "language_index", 0)
	slider_rounds.value = cfg.get_value("gameplay", "rounds", GameConfig.current_rounds)
	slider_shopping.value = cfg.get_value("gameplay", "shopping_list_size", GameConfig.shopping_list_size)

func _apply() -> void:
	AudioManager.set_bus_volume(&"Master", slider_master.value)
	AudioManager.set_bus_volume(&"Music",  slider_bgm.value)
	AudioManager.set_bus_volume(&"SFX",    slider_sfx.value)

	if chk_fullscreen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	GameConfig.current_rounds = int(slider_rounds.value)
	GameConfig.shopping_list_size = int(slider_shopping.value)

	_save_settings()
	AudioManager.play_sfx("menu_confirm")

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", slider_master.value)
	cfg.set_value("audio", "bgm_volume",    slider_bgm.value)
	cfg.set_value("audio", "sfx_volume",    slider_sfx.value)
	cfg.set_value("video", "fullscreen",    chk_fullscreen.button_pressed)
	cfg.set_value("locale", "language_index", opt_language.selected)
	cfg.set_value("gameplay", "rounds",     int(slider_rounds.value))
	cfg.set_value("gameplay", "shopping_list_size", int(slider_shopping.value))
	cfg.save(SETTINGS_PATH)

func _go_back() -> void:
	SceneRouter.goto(SceneRouter.Screen.MAIN_MENU)
