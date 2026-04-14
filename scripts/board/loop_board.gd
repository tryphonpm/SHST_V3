## Visual board node that renders pavement cells, a building area, and shop markers.
## The layout is provided by a BoardGraph injected via build() — this class
## never hardcodes cell counts or positions.
##
## Reminder: shop ↔ cell anchoring is defined in BoardNode.shop_id.
## The visual positions computed here are cosmetic only.
##
## TODO: replace placeholder ColorRect pavement tiles with real art under assets/boards/
class_name LoopBoard
extends Node2D

signal board_ready
signal shops_placed(placements: Array)

var _graph: BoardGraph = null
## Cells keyed by node_id for O(1) lookup.
var _cells_by_id: Dictionary = {}  # StringName → PavementCell
var _shop_markers: Dictionary = {}  # StringName (node_id) → ShopMarker
var _building_area: BuildingArea = null

func _ready() -> void:
	pass

# ═══════════════════════════════════════════════════════════════
#  Public build entry point
# ═══════════════════════════════════════════════════════════════

## Build the board for one game session.
## `graph` defines the node layout, adjacency, and shop anchoring.
## `rng` controls shop placement randomisation (seeded for reproducibility).
## Must be called once from board_game._ready() BEFORE _spawn_tokens().
func build(graph: BoardGraph, rng: RandomNumberGenerator) -> void:
	_graph = graph
	_validate_shops()
	_build_cells()
	_build_building()
	_place_shops(rng)
	board_ready.emit()

func get_graph() -> BoardGraph:
	return _graph

# ═══════════════════════════════════════════════════════════════
#  Cell construction
# ═══════════════════════════════════════════════════════════════

func _build_cells() -> void:
	for nid: StringName in _graph.nodes:
		var bn: BoardNode = _graph.nodes[nid]
		var cell := PavementCell.new()
		cell.index          = bn.display_index
		cell.node_id        = bn.id
		cell.position       = bn.position
		cell.side           = bn.side
		cell.is_intersection = bn is Intersection
		add_child(cell)
		_cells_by_id[bn.id] = cell

# ═══════════════════════════════════════════════════════════════
#  Building area
# ═══════════════════════════════════════════════════════════════

func _build_building() -> void:
	var inner_rect := _graph.building_rect
	if inner_rect.size == Vector2.ZERO:
		return
	_building_area = BuildingArea.new()
	_building_area.setup(inner_rect)
	add_child(_building_area)

# ═══════════════════════════════════════════════════════════════
#  Shop placement (inside the building)
# ═══════════════════════════════════════════════════════════════

func _place_shops(rng: RandomNumberGenerator) -> void:
	var shops_layer := Node2D.new()
	shops_layer.name = "ShopsLayer"
	add_child(shops_layer)

	var inner_rect := _graph.building_rect
	if inner_rect.size == Vector2.ZERO:
		return

	var placement_margin := GameConfig.SHOP_INNER_MARGIN + GameConfig.SHOP_VISUAL_SIZE.x * 0.5
	var placement_rect   := inner_rect.grow(-placement_margin)

	var placed_positions: Array[Vector2] = []
	var placements: Array = []

	for id: StringName in _graph.nodes:
		var bn: BoardNode = _graph.nodes[id]
		if bn.shop_id == &"":
			continue

		var cell := get_cell_by_node_id(bn.id)
		if cell == null:
			push_error("LoopBoard: no cell for node '%s' (shop '%s')" % [bn.id, bn.shop_id])
			continue

		var shop := CatalogManager.get_shop(bn.shop_id)
		if shop == null:
			push_warning(
				"LoopBoard: shop '%s' not in CatalogManager" % bn.shop_id
			)
			continue

		var target := _pick_shop_position(rng, placement_rect, placed_positions)
		placed_positions.append(target)

		var marker := ShopMarker.new()
		shops_layer.add_child(marker)
		marker.setup(shop, cell, target)
		_shop_markers[bn.id] = marker

		placements.append({
			"shop_id":  bn.shop_id,
			"node_id":  bn.id,
			"position": target,
		})

	shops_placed.emit(placements)

func _pick_shop_position(
	rng:            RandomNumberGenerator,
	placement_rect: Rect2,
	placed:         Array[Vector2]
) -> Vector2:
	for _attempt in GameConfig.SHOP_PLACEMENT_MAX_ATTEMPTS:
		var candidate := Vector2(
			rng.randf_range(placement_rect.position.x, placement_rect.end.x),
			rng.randf_range(placement_rect.position.y, placement_rect.end.y)
		)
		var ok := true
		for other in placed:
			if candidate.distance_to(other) < GameConfig.SHOP_MIN_SEPARATION:
				ok = false
				break
		if ok:
			return candidate

	push_warning("LoopBoard: max placement attempts reached — using grid fallback")
	var cols   := 3
	var col    := placed.size() % cols
	var row    := placed.size() / cols
	var step_x := placement_rect.size.x / cols
	var step_y := maxf(placement_rect.size.y / 2.0, GameConfig.SHOP_MIN_SEPARATION)
	return (placement_rect.position
		+ Vector2(col * step_x + step_x * 0.5, row * step_y + step_y * 0.5)
	).clamp(placement_rect.position, placement_rect.end)

# ═══════════════════════════════════════════════════════════════
#  Validation
# ═══════════════════════════════════════════════════════════════

func _validate_shops() -> void:
	var seen: Dictionary = {}  # node_id → shop_id
	for id: StringName in _graph.nodes:
		var bn: BoardNode = _graph.nodes[id]
		if bn.shop_id == &"":
			continue
		if seen.values().has(bn.shop_id):
			push_error("LoopBoard: duplicate shop_id '%s' on node '%s'" % [bn.shop_id, id])
		seen[id] = bn.shop_id

# ═══════════════════════════════════════════════════════════════
#  Lookup helpers
# ═══════════════════════════════════════════════════════════════

func get_cell_by_node_id(id: StringName) -> PavementCell:
	return _cells_by_id.get(id, null)

func get_cell_count() -> int:
	return _cells_by_id.size()

func get_shop_marker_at_node(node_id: StringName) -> ShopMarker:
	return _shop_markers.get(node_id, null)

func has_shop_at_node(node_id: StringName) -> bool:
	return _shop_markers.has(node_id)
