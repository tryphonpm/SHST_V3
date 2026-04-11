# Data-driven catalog for Products and Shops.
#
# Extension pattern: to add a new product or shop, drop a new .tres file into
# the corresponding folder (res://data/products/ or res://data/shops/) — no
# code changes required. CatalogManager discovers and loads all resources at
# startup automatically.
extends Node

signal catalog_loaded

var _products: Dictionary = {}  # StringName → Product
var _shops: Dictionary = {}     # StringName → Shop

func _ready() -> void:
	_load_shops()
	_load_products()
	_validate()
	catalog_loaded.emit()

# ---- Loaders ----

func _load_shops() -> void:
	var dir := DirAccess.open(GameConfig.SHOPS_DIR)
	if dir == null:
		push_error("CatalogManager: cannot open shops directory '%s'" % GameConfig.SHOPS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := GameConfig.SHOPS_DIR + file_name
			var res = load(path)
			if res is Shop:
				_shops[res.id] = res
			else:
				push_warning("CatalogManager: '%s' is not a Shop resource" % path)
		file_name = dir.get_next()

func _load_products() -> void:
	var dir := DirAccess.open(GameConfig.PRODUCTS_DIR)
	if dir == null:
		push_error("CatalogManager: cannot open products directory '%s'" % GameConfig.PRODUCTS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := GameConfig.PRODUCTS_DIR + file_name
			var res = load(path)
			if res is Product:
				_products[res.id] = res
			else:
				push_warning("CatalogManager: '%s' is not a Product resource" % path)
		file_name = dir.get_next()

func _validate() -> void:
	for product_id in _products:
		var product: Product = _products[product_id]
		if not _shops.has(product.shop_id):
			push_error("CatalogManager: Product '%s' references unknown shop_id '%s'" % [
				product.id, product.shop_id
			])

# ---- Public API ----

func get_all_products() -> Array[Product]:
	var arr: Array[Product] = []
	for key in _products:
		arr.append(_products[key])
	return arr

func get_all_shops() -> Array[Shop]:
	var arr: Array[Shop] = []
	for key in _shops:
		arr.append(_shops[key])
	return arr

func get_product(id: StringName) -> Product:
	if _products.has(id):
		return _products[id]
	push_warning("CatalogManager: unknown product '%s'" % id)
	return null

func get_shop(id: StringName) -> Shop:
	if _shops.has(id):
		return _shops[id]
	push_warning("CatalogManager: unknown shop '%s'" % id)
	return null

func get_products_by_shop(shop_id: StringName) -> Array[Product]:
	var arr: Array[Product] = []
	for key in _products:
		var p: Product = _products[key]
		if p.shop_id == shop_id:
			arr.append(p)
	return arr

## Weighted random pick of `size` unique product ids.
func generate_shopping_list(size: int, rng: RandomNumberGenerator = null) -> Array[StringName]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var pool: Array[Product] = get_all_products()
	var result: Array[StringName] = []
	size = mini(size, pool.size())

	var total_weight := 0.0
	for p in pool:
		total_weight += p.weight

	while result.size() < size and pool.size() > 0:
		var roll := rng.randf() * total_weight
		var cumulative := 0.0
		for i in pool.size():
			cumulative += pool[i].weight
			if roll <= cumulative:
				result.append(pool[i].id)
				total_weight -= pool[i].weight
				pool.remove_at(i)
				break

	return result
