extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var logo: TextureRect = $CenterContainer/VBox/Logo
@onready var title_label: Label = $CenterContainer/VBox/TitleLabel
@onready var press_label: Label = $CenterContainer/VBox/PressLabel
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

var _cutscene_done := false

func _ready() -> void:
	AudioManager.play_bgm("home_theme")
	_start_cutscene()

func _start_cutscene() -> void:
	animation_player.play("intro")
	animation_player.animation_finished.connect(_on_cutscene_finished, CONNECT_ONE_SHOT)

func _unhandled_input(event: InputEvent) -> void:
	if _cutscene_done:
		return
	var dominated: bool = (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	)
	if dominated:
		_skip_cutscene()

func _skip_cutscene() -> void:
	if _cutscene_done:
		return
	_cutscene_done = true
	animation_player.stop()
	video_player.stop()
	_go_to_menu()

func _on_cutscene_finished(_anim_name: String) -> void:
	_cutscene_done = true
	_go_to_menu()

func _go_to_menu() -> void:
	SceneRouter.goto(SceneRouter.Screen.MAIN_MENU)
