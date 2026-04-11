extends Node

## Emitted when the full game starts (board is loaded, players seated).
signal game_started
## Emitted at the end of each round.
signal round_ended(round_number: int)
## Emitted when win conditions are met and the game is over.
signal game_over(winner: PlayerData)
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

var current_round: int = 1
var players: Array[PlayerData] = []
var is_game_active: bool = false
var _local_player: PlayerData = null

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
	current_round = 1
	is_game_active = true
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
		# Only collect if it's on the list and not yet collected
		if pid in player.shopping_list and pid not in player.collected_items:
			player.collect_product(pid)
			product_purchased.emit(player.player_id, pid)
			product_collected.emit(player.player_id, pid)

			if player.is_shopping_complete():
				player_finished_shopping.emit(player.player_id)
			return true

	return false

# ---- Round lifecycle ----

func advance_round() -> void:
	current_round += 1
	round_ended.emit(current_round - 1)
	if current_round > GameConfig.current_rounds:
		_end_game()

func _end_game() -> void:
	is_game_active = false
	var winner := _determine_winner()
	game_over.emit(winner)

func _determine_winner() -> PlayerData:
	var best: PlayerData = players[0]
	for p in players:
		if p.stars > best.stars:
			best = p
		elif p.stars == best.stars and p.coins > best.coins:
			best = p
	return best

# ---- Queries ----

func get_player(id: int) -> PlayerData:
	if id >= 0 and id < players.size():
		return players[id]
	return null

func get_player_count() -> int:
	return players.size()

# ---- Internal ----

func _on_player_data_changed(property_name: String, player: PlayerData) -> void:
	player_data_changed.emit(player, property_name)
