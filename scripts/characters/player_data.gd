class_name PlayerData
extends Resource

signal data_changed(property_name: String)

@export var player_id: int = -1
@export var display_name: String = "Player"
@export var color: Color = Color.WHITE
@export var coins: int = GameConfig.COINS_START
@export var stars: int = 0
@export var items: Array[String] = []
## Current position in the board graph, identified by node ID.
@export var board_node_id: StringName = &""
@export var is_ai: bool = false
@export var avatar_id: String = ""
@export var shopping_list: Array[StringName] = []
@export var collected_items: Array[StringName] = []
@export var laps_completed: int = 0

func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	data_changed.emit("coins")

func add_stars(amount: int) -> void:
	stars = maxi(stars + amount, 0)
	data_changed.emit("stars")

func add_item(item_key: String) -> void:
	items.append(item_key)
	data_changed.emit("items")

func remove_item(item_key: String) -> bool:
	var idx := items.find(item_key)
	if idx == -1:
		return false
	items.remove_at(idx)
	data_changed.emit("items")
	return true

func set_board_node(id: StringName) -> void:
	board_node_id = id
	data_changed.emit("board_node_id")

func set_shopping_list(list: Array[StringName]) -> void:
	shopping_list = list.duplicate()
	collected_items.clear()
	data_changed.emit("shopping_list")

func collect_product(product_id: StringName) -> void:
	collected_items.append(product_id)
	data_changed.emit("collected_items")

func increment_laps() -> void:
	laps_completed += 1
	data_changed.emit("laps_completed")

func has_finished_street() -> bool:
	return laps_completed >= GameConfig.required_laps

func is_shopping_complete() -> bool:
	return shopping_list.all(func(id: StringName) -> bool: return id in collected_items)

func set_avatar(new_avatar_id: String) -> void:
	avatar_id = new_avatar_id
	var info := AvatarCatalog.get_avatar(new_avatar_id)
	if not info.is_empty():
		display_name = info["display_name"]
		color = info["color"]
	data_changed.emit("avatar")

func reset() -> void:
	coins = GameConfig.COINS_START
	stars = 0
	items.clear()
	shopping_list.clear()
	collected_items.clear()
	board_node_id = &""
	laps_completed = 0
	data_changed.emit("reset")
