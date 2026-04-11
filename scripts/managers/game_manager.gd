extends Node

## Emitted when the full game starts (board is loaded, players seated).
signal game_started
## Emitted whenever any player's data changes (proxied from PlayerData).
signal player_data_changed(player: PlayerData, property_name: String)
## Emitted when a player's shopping list is assigned at session start.
signal shopping_list_assigned(player_id: int, list: Array[StringName])
## Emitted when a player successfully buys a product.
signal product_purchased(player_id: int, product_id: StringName)
## Emitted when a player has collected every item on their list.
signal player_finished_shopping(player_id: int)
## Emitted when a product is collected via the fake minigame flow.
signal product_collected(player_id: int, product_id: StringName)
## Emitted once when is_game_over() first becomes true (after a player_finished_street).
## `results` is the sorted ranking array from compute_final_ranking().
signal game_over_ready(results: Array)

var players: Array[PlayerData] = []
var is_game_active: bool = false
var _local_player: PlayerData = null
var _game_over_emitted := false

func _ready() -> void:
	TurnManager.player_finished_street.connect(_on_player_finished_street)

# ---- Setup ----

func register_player(display_name: String, color: Color, is_ai: bool = false) -> PlayerData:
	if players.size() >= GameConfig.MAX_PLAYERS:
		push_warning("Cannot add more than %d players." % GameConfig.MAX_PLAYERS)
		return null
	var pd := PlayerData.new()
	pd.player_id = players.size()
	pd.display_name = display_name
	pd.color = color
	pd.is_ai = is_ai
	pd.data_changed.connect(_on_player_data_changed.bind(pd))
	players.append(pd)
	return pd

## Set the local player's avatar before starting. Creates or updates the PlayerData.
func set_local_player_avatar(avatar_id: String) -> PlayerData:
	var info := AvatarCatalog.get_avatar(avatar_id)
	if info.is_empty():
		push_warning("Invalid avatar_id: %s" % avatar_id)
		return null
	if _local_player == null:
		_local_player = register_player(info["display_name"], info["color"])
	if _local_player:
		_local_player.set_avatar(avatar_id)
	return _local_player

func get_local_player() -> PlayerData:
	return _local_player

func clear_players() -> void:
	players.clear()
	_local_player = null

func start_game() -> void:
	if players.size() < GameConfig.MIN_PLAYERS:
		push_warning("Need at least %d players to start." % GameConfig.MIN_PLAYERS)
		return
	is_game_active = true
	_game_over_emitted = false
	for p in players:
		p.reset()
	game_started.emit()

# ---- Shopping ----

## Assign a random shopping list to every registered player.
func assign_shopping_lists() -> void:
	for p in players:
		var list := CatalogManager.generate_shopping_list(GameConfig.shopping_list_size)
		p.set_shopping_list(list)
		shopping_list_assigned.emit(p.player_id, list)

## Attempt to purchase a product at a shop. Returns true on success.
func try_purchase(player_id: int, product_id: StringName, shop_id: StringName) -> bool:
	var player := get_player(player_id)
	if player == null:
		return false

	var product := CatalogManager.get_product(product_id)
	if product == null:
		return false

	if product.shop_id != shop_id:
		push_warning("Product '%s' does not belong to shop '%s'" % [product_id, shop_id])
		return false

	if player.coins < product.base_price:
		push_warning("Player %d cannot afford '%s' (cost %d, has %d)" % [
			player_id, product_id, product.base_price, player.coins
		])
		return false

	player.add_coins(-product.base_price)
	player.collect_product(product_id)
	product_purchased.emit(player_id, product_id)

	if player.is_shopping_complete():
		player_finished_shopping.emit(player_id)

	return true

## Collect the first matching product from a shop for the current player.
## This is the only entry point that writes to PlayerData.collected_items.
## TODO: multi-product shops — currently only the first product per shop is
## collected; later iterations should let the player pick.
func collect_product_for_current_player(shop_id: StringName) -> bool:
	var player := TurnManager.get_current_player()
	if player == null:
		return false

	var products := CatalogManager.get_products_by_shop(shop_id)
	if products.is_empty():
		push_warning("No products found for shop '%s'" % shop_id)
		return false

	for product in products:
		var pid: StringName = product.id
		if pid in player.shopping_list and pid not in player.collected_items:
			player.collect_product(pid)
			product_purchased.emit(player.player_id, pid)
			product_collected.emit(player.player_id, pid)

			if player.is_shopping_complete():
				player_finished_shopping.emit(player.player_id)
			return true

	return false

# ---- End condition ----

## True when every registered player has completed the required street laps.
func is_game_over() -> bool:
	if players.is_empty():
		return false
	return players.all(func(p: PlayerData) -> bool: return p.has_finished_street())

## Returns players sorted by:
##   1. collected_items count  (desc)
##   2. laps_completed         (desc)
##   3. coins                  (desc)
##   4. player_id              (asc) — stable final fallback
func compute_final_ranking() -> Array:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		if a.collected_items.size() != b.collected_items.size():
			return a.collected_items.size() > b.collected_items.size()
		if a.laps_completed != b.laps_completed:
			return a.laps_completed > b.laps_completed
		if a.coins != b.coins:
			return a.coins > b.coins
		return a.player_id < b.player_id
	)
	return sorted

# ---- Queries ----

func get_player(id: int) -> PlayerData:
	if id >= 0 and id < players.size():
		return players[id]
	return null

func get_player_count() -> int:
	return players.size()

# ---- Internal ----

func _on_player_finished_street(_player_id: int) -> void:
	if _game_over_emitted:
		return
	if is_game_over():
		is_game_active = false
		_game_over_emitted = true
		game_over_ready.emit(compute_final_ranking())

func _on_player_data_changed(property_name: String, player: PlayerData) -> void:
	player_data_changed.emit(player, property_name)
