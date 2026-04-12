## Visual board node that renders pavement cells, a building area, and shop markers.
## The spatial layout is provided by a BoardTopology injected via build() — this
## class never hardcodes cell counts or positions.
##
## Reminder: shop ↔ cell anchoring is authoritative in BoardTopology.get_shop_cell_indices().
## The visual positions computed here are cosmetic only.
##
## TODO: replace placeholder ColorRect pavement tiles with real art under assets/boards/
class_name LoopBoard
extends Node2D

## Emitted after build() finishes placing cells, building, and shops.
signal board_ready
## Emitted with debug/replay metadata for every shop placed.
signal shops_placed(placements: Array)

var _topology: BoardTopology = null
var _cells: Array[PavementCell] = []
var _shop_markers: Dictionary = {}  # cell_index (int) → ShopMarker
var _building_area: BuildingArea = null

func _ready() -> void:
	# build() is called explicitly by board_game.gd with the session topology
	# and RNG so shop positions are seeded and reproducible.
	pass

# ═══════════════════════════════════════════════════════════════
#  Public build entry point
# ═══════════════════════════════════════════════════════════════

## Build the board for one game session.
## `topology` defines the cell layout and traversal rules.
## `rng` controls shop placement randomisation (seeded for reproducibility).
## Must be called once from board_game._ready() BEFORE _spawn_tokens().
func build(topology: BoardTopology, rng: RandomNumberGenerator) -> void:
	_topology = topology
	_validate_shop_indices()
	_build_cells()
	_build_building()
	_place_shops(rng)
	board_ready.emit()

## The topology backing this board (available after build()).
func get_topology() -> BoardTopology:
	return _topology

# ═══════════════════════════════════════════════════════════════
#  Cell construction
# ═══════════════════════════════════════════════════════════════

func _build_cells() -> void:
	var topo_cells := _topology.get_cells()
	for tc in topo_cells:
		var cell := PavementCell.new()
		cell.index    = tc.index
		cell.position = tc.position
		add_child(cell)
		_cells.append(cell)

# ═══════════════════════════════════════════════════════════════
#  Building area
# ═══════════════════════════════════════════════════════════════

func _build_building() -> void:
	var inner_rect := _topology.get_inner_rect()
	if inner_rect.size == Vector2.ZERO:
		return  # topology has no building interior
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

	var inner_rect := _topology.get_inner_rect()
	if inner_rect.size == Vector2.ZERO:
		return

	var placement_margin := GameConfig.SHOP_INNER_MARGIN + GameConfig.SHOP_VISUAL_SIZE.x * 0.5
	var placement_rect   := inner_rect.grow(-placement_margin)

	var placed_positions: Array[Vector2] = []
	var placements: Array = []
	var shop_indices := _topology.get_shop_cell_indices()

	for shop_id: StringName in shop_indices:
		var cell_index: int = shop_indices[shop_id]
		var cell := get_cell(cell_index)
		if cell == null:
			push_error("LoopBoard: no cell at index %d for shop '%s'" % [cell_index, shop_id])
			continue

		var shop := CatalogManager.get_shop(shop_id)
		if shop == null:
			push_warning("LoopBoard: shop '%s' not found in CatalogManager — skipping visual" % shop_id)
			continue

		var target := _pick_shop_position(rng, placement_rect, placed_positions)
		placed_positions.append(target)

		var marker := ShopMarker.new()
		shops_layer.add_child(marker)
		marker.setup(shop, cell, target)
		_shop_markers[cell_index] = marker

		placements.append({
			"shop_id":    shop_id,
			"cell_index": cell_index,
			"position":   target,
		})

	shops_placed.emit(placements)

## TODO: smarter shop placement using a Poisson-disk sampler if the building
##       rect becomes crowded with more than ~6 shops.
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

	push_warning("LoopBoard: max placement attempts reached for shop %d — using grid fallback" % placed.size())
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

func _validate_shop_indices() -> void:
	var shop_indices := _topology.get_shop_cell_indices()
	var cell_count   := _topology.get_cell_count()
	var seen: Dictionary = {}
	for sid: StringName in shop_indices:
		var idx: int = shop_indices[sid]
		if idx < 0 or idx >= cell_count:
			push_error("LoopBoard: shop '%s' anchor index %d is outside [0, %d)" % [
				sid, idx, cell_count
			])
		if seen.has(idx):
			push_error("LoopBoard: duplicate anchor cell %d for shops '%s' and '%s'" % [
				idx, seen[idx], sid
			])
		seen[idx] = sid

# ═══════════════════════════════════════════════════════════════
#  Lookup helpers
# ═══════════════════════════════════════════════════════════════

func get_cell(idx: int) -> PavementCell:
	if idx >= 0 and idx < _cells.size():
		return _cells[idx]
	return null

func get_cell_count() -> int:
	return _cells.size()

func get_shop_marker_at_cell(index: int) -> ShopMarker:
	return _shop_markers.get(index, null)

func has_shop_at_cell(index: int) -> bool:
	return _shop_markers.has(index)

func get_cell_grid_edge(index: int) -> StringName:
	return _topology.get_cell_edge_name(index)
