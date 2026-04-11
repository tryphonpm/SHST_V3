class_name PlayerData
extends Resource

signal data_changed(property_name: String)

@export var player_id: int = -1
@export var display_name: String = "Player"
@export var color: Color = Color.WHITE
@export var coins: int = GameConfig.COINS_START
@export var stars: int = 0
@export var items: Array[String] = []
@export var board_position: int = 0  # index into the board's space array
@export var is_ai: bool = false
@export var avatar_id: String = ""
@export var shopping_list: Array[StringName] = []
@export var collected_items: Array[StringName] = []

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

func set_board_position(new_pos: int) -> void:
	board_position = new_pos
	data_changed.emit("board_position")

func set_shopping_list(list: Array[StringName]) -> void:
	shopping_list = list.duplicate()
	collected_items.clear()
	data_changed.emit("shopping_list")

func collect_product(product_id: StringName) -> void:
	collected_items.append(product_id)
	data_changed.emit("collected_items")

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
	board_position = 0
	data_changed.emit("reset")
