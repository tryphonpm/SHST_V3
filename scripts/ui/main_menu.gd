extends Control

@onready var btn_play: Button = $VBox/Buttons/BtnPlay
@onready var btn_tutorial: Button = $VBox/Buttons/BtnTutorial
@onready var btn_parameters: Button = $VBox/Buttons/BtnParameters
@onready var btn_credits: Button = $VBox/Buttons/BtnCredits
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	version_label.text = "v%s" % GameConfig.VERSION

	btn_play.pressed.connect(_on_play)
	btn_tutorial.pressed.connect(_on_tutorial)
	btn_parameters.pressed.connect(_on_parameters)
	btn_credits.pressed.connect(_on_credits)

	btn_play.focus_entered.connect(_on_focus)
	btn_tutorial.focus_entered.connect(_on_focus)
	btn_parameters.focus_entered.connect(_on_focus)
	btn_credits.focus_entered.connect(_on_focus)

	# Ensure gamepad/keyboard accessibility
	btn_play.grab_focus()

func _on_play() -> void:
	AudioManager.play_sfx("menu_confirm")
	SceneRouter.goto(SceneRouter.Screen.CUSTOMIZATION)

func _on_tutorial() -> void:
	AudioManager.play_sfx("menu_confirm")
	SceneRouter.goto(SceneRouter.Screen.TUTORIAL)

func _on_parameters() -> void:
	AudioManager.play_sfx("menu_confirm")
	SceneRouter.goto(SceneRouter.Screen.PARAMETERS)

func _on_credits() -> void:
	AudioManager.play_sfx("menu_confirm")
	SceneRouter.goto(SceneRouter.Screen.CREDITS)

func _on_focus() -> void:
	AudioManager.play_sfx("menu_move")
