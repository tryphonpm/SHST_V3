class_name StreetBoard
extends Node2D

signal board_ready

var _cells: Array[PavementCell] = []

func _ready() -> void:
	_build_street()
	board_ready.emit()

func _build_street() -> void:
	_validate_shop_indices()

	for i in GameConfig.STREET_CELL_COUNT:
		var cell := PavementCell.new()
		cell.index = i
		cell.position = Vector2(i * GameConfig.CELL_SIZE.x, 0)

		var sid: StringName = _shop_id_for_index(i)
		if sid != &"":
			cell.shop_id = sid

		add_child(cell)
		_cells.append(cell)

func _shop_id_for_index(idx: int) -> StringName:
	for sid in GameConfig.SHOP_CELL_INDICES:
		if GameConfig.SHOP_CELL_INDICES[sid] == idx:
			return sid
	return &""

func _validate_shop_indices() -> void:
	var seen: Dictionary = {}
	for sid in GameConfig.SHOP_CELL_INDICES:
		var idx: int = GameConfig.SHOP_CELL_INDICES[sid]
		if idx < 0 or idx >= GameConfig.STREET_CELL_COUNT:
			push_error("StreetBoard: shop '%s' index %d out of range [0, %d)" % [
				sid, idx, GameConfig.STREET_CELL_COUNT
			])
		if seen.has(idx):
			push_error("StreetBoard: duplicate cell index %d for shops '%s' and '%s'" % [
				idx, seen[idx], sid
			])
		seen[idx] = sid

func get_cell(idx: int) -> PavementCell:
	if idx >= 0 and idx < _cells.size():
		return _cells[idx]
	return null

func get_shop_cells() -> Array[PavementCell]:
	var arr: Array[PavementCell] = []
	for c in _cells:
		if c.is_shop():
			arr.append(c)
	return arr

func get_cell_count() -> int:
	return _cells.size()
