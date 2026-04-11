extends Node

## Emitted when a minigame scene is fully loaded and ready.
signal minigame_started(scene_path: String)
## Emitted when the minigame ends. `results` maps player_id → placement (1st, 2nd…).
signal minigame_ended(results: Dictionary)
## Emitted when the placeholder shop minigame finishes.
signal minigame_finished(shop_id: StringName)

const MINIGAME_ROOT_PATH := "res://scenes/minigames/"
const FAKE_MINIGAME_SCENE := "res://scenes/minigames/FakeMinigame.tscn"

var _active_minigame: Node = null
var _previous_scene: Node = null

# ---- Full scene-swap minigames (original API) ----

func start_minigame(scene_name: String) -> void:
	var path := MINIGAME_ROOT_PATH + scene_name + ".tscn"
	if not ResourceLoader.exists(path):
		push_error("Minigame scene not found: %s" % path)
		return

	var packed: PackedScene = load(path)
	_active_minigame = packed.instantiate()

	_previous_scene = get_tree().current_scene
	get_tree().current_scene.visible = false

	get_tree().root.add_child(_active_minigame)
	get_tree().current_scene = _active_minigame

	minigame_started.emit(path)

func finish_minigame(results: Dictionary) -> void:
	_distribute_rewards(results)

	if _active_minigame:
		_active_minigame.queue_free()
		_active_minigame = null

	if _previous_scene:
		_previous_scene.visible = true
		get_tree().current_scene = _previous_scene
		_previous_scene = null

	minigame_ended.emit(results)

func _distribute_rewards(results: Dictionary) -> void:
	for player_id in results.keys():
		var placement: int = results[player_id]
		var player := GameManager.get_player(player_id)
		if player == null:
			continue
		if placement == 1:
			player.add_coins(GameConfig.COINS_MINIGAME_WIN)
		else:
			player.add_coins(GameConfig.COINS_MINIGAME_LOSE)

# ---- Placeholder shop minigame (modal overlay) ----

## Run a timed fake minigame modal for a shop landing.
## After the duration, collects the product and calls TurnManager.end_step_action().
func run_placeholder(shop_id: StringName, minigame_layer: CanvasLayer) -> void:
	var packed := load(FAKE_MINIGAME_SCENE) as PackedScene
	if packed == null:
		push_error("Cannot load FakeMinigame scene")
		TurnManager.end_step_action()
		return

	var instance := packed.instantiate()
	minigame_layer.add_child(instance)

	var shop := CatalogManager.get_shop(shop_id)
	if instance.has_method("setup"):
		instance.setup(shop)

	await get_tree().create_timer(GameConfig.FAKE_MINIGAME_DURATION).timeout

	GameManager.collect_product_for_current_player(shop_id)

	instance.queue_free()
	minigame_finished.emit(shop_id)
	TurnManager.end_step_action()
