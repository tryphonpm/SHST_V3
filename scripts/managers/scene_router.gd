extends Node

signal scene_changed(screen: Screen)

enum Screen {
	HOME,
	MAIN_MENU,
	TUTORIAL,
	PARAMETERS,
	CREDITS,
	CUSTOMIZATION,
	GAME,
}

const _SCREEN_PATHS: Dictionary = {
	Screen.HOME:          "res://scenes/ui/HomeScreen.tscn",
	Screen.MAIN_MENU:     "res://scenes/ui/MainMenu.tscn",
	Screen.TUTORIAL:      "res://scenes/ui/TutorialScene.tscn",
	Screen.PARAMETERS:    "res://scenes/ui/ParametersScene.tscn",
	Screen.CREDITS:       "res://scenes/ui/CreditsScene.tscn",
	Screen.CUSTOMIZATION: "res://scenes/ui/GameCustomizationScene.tscn",
	Screen.GAME:          "res://scenes/board/BoardGame.tscn",
}

var current_screen: Screen = Screen.HOME

func goto(screen: Screen) -> void:
	if not _SCREEN_PATHS.has(screen):
		push_error("SceneRouter: unknown screen %d" % screen)
		return
	current_screen = screen
	var err := get_tree().change_scene_to_file(_SCREEN_PATHS[screen])
	if err != OK:
		push_error("SceneRouter: failed to load %s" % _SCREEN_PATHS[screen])
		return
	scene_changed.emit(screen)
