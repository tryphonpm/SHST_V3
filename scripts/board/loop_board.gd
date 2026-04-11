## Rectangular pavement loop of 34 cells surrounding a central BuildingArea.
## Shops are placed INSIDE the building with random positions (re-rolled once per
## session via the shared RNG from board_game.gd) and tethered to their anchor
## pavement cell by a Line2D.
##
## Reminder: shop ↔ cell anchoring is authoritative in GameConfig.SHOP_CELL_INDICES.
## The visual positions computed here are cosmetic only.
##
## TODO: replace placeholder ColorRect pavement tiles with real art under assets/boards/
class_name LoopBoard
extends Node2D

## Emitted after build() finishes placing cells, building, and shops.
signal board_ready
## Emitted with debug/replay metadata for every shop placed.
## Each entry: { shop_id, cell_index, position }
signal shops_placed(placements: Array)

var _cells: Array[PavementCell] = []
var _shop_markers: Dictionary = {}  # cell_index (int) → ShopMarker
var _building_area: BuildingArea = null

func _ready() -> void:
	# build() is called explicitly by board_game.gd with the session RNG so
	# shop positions are seeded and reproducible.
	pass

# ═══════════════════════════════════════════════════════════════
#  Public build entry point
# ═══════════════════════════════════════════════════════════════

## Build the board for one game session.
## Must be called once from board_game._ready() BEFORE _spawn_tokens().
func build(rng: RandomNumberGenerator) -> void:
	_validate_shop_indices()
	_build_cells()
	_build_building()
	_place_shops(rng)
	board_ready.emit()

# ═══════════════════════════════════════════════════════════════
#  Cell construction
# ═══════════════════════════════════════════════════════════════

func _build_cells() -> void:
	var positions := _build_loop_positions()
	assert(positions.size() == GameConfig.LOOP_CELL_COUNT,
		"LoopBoard: _build_loop_positions() returned %d positions, expected %d" % [
			positions.size(), GameConfig.LOOP_CELL_COUNT
		])
	for i in positions.size():
		var cell := PavementCell.new()
		cell.index = i
		cell.position = positions[i]
		add_child(cell)
		_cells.append(cell)

## Returns LOOP_CELL_COUNT world positions walking clockwise from the top-left corner.
## Coordinate system: top-left cell is at (0, 0); x increases right, y increases down.
func _build_loop_positions() -> Array[Vector2]:
	var pos: Array[Vector2] = []
	var cs := GameConfig.CELL_SIZE

	# Top row: left → right (cells 0 .. LOOP_TOP_COUNT-1)
	for i in GameConfig.LOOP_TOP_COUNT:
		pos.append(Vector2(i * cs.x, 0.0))

	# Right column: top → bottom (cells LOOP_TOP_COUNT .. +LOOP_RIGHT_COUNT-1)
	var right_x := (GameConfig.LOOP_TOP_COUNT - 1) * cs.x
	for i in GameConfig.LOOP_RIGHT_COUNT:
		pos.append(Vector2(right_x, (i + 1) * cs.y))

	# Bottom row: right → left (cells .. +LOOP_BOTTOM_COUNT-1)
	var bottom_y := GameConfig.LOOP_RIGHT_COUNT * cs.y
	for i in GameConfig.LOOP_BOTTOM_COUNT:
		pos.append(Vector2((GameConfig.LOOP_TOP_COUNT - 2 - i) * cs.x, bottom_y))

	# Left column: bottom → top (cells .. LOOP_CELL_COUNT-1)
	for i in GameConfig.LOOP_LEFT_COUNT:
		pos.append(Vector2(0.0, (GameConfig.LOOP_RIGHT_COUNT - 1 - i) * cs.y))

	# Loop-closure assertion: cell 33 must be exactly one cell away from cell 0.
	if pos.size() == GameConfig.LOOP_CELL_COUNT:
		var gap := pos[GameConfig.LOOP_END_INDEX].distance_to(pos[GameConfig.LOOP_START_INDEX])
		assert(
			is_equal_approx(gap, GameConfig.CELL_SIZE.x) or is_equal_approx(gap, GameConfig.CELL_SIZE.y),
			"LoopBoard: loop does not close — gap between cell %d and cell 0 is %.1fpx" % [
				GameConfig.LOOP_END_INDEX, gap
			]
		)
	return pos

# ═══════════════════════════════════════════════════════════════
#  Building area
# ═══════════════════════════════════════════════════════════════

func _build_building() -> void:
	var inner_rect := _compute_inner_rect()
	_building_area = BuildingArea.new()
	_building_area.setup(inner_rect)
	# Added after cells so it renders above them; shops layer added after this.
	add_child(_building_area)

## Computes the building rectangle in LoopBoard local coordinates.
## The building fills the interior of the loop minus BUILDING_INNER_PADDING.
func _compute_inner_rect() -> Rect2:
	var cs  := GameConfig.CELL_SIZE
	var pad := GameConfig.BUILDING_INNER_PADDING

	# Inner boundary: just inside the perimeter cell sprites (cell centres ± half-size).
	var inner_left   := cs.x * 0.5
	var inner_top    := cs.y * 0.5
	var inner_right  := (GameConfig.LOOP_TOP_COUNT - 1) * cs.x - cs.x * 0.5
	var inner_bottom := GameConfig.LOOP_RIGHT_COUNT * cs.y - cs.y * 0.5

	return Rect2(
		Vector2(inner_left  + pad.x, inner_top    + pad.y),
		Vector2(inner_right - inner_left - 2.0 * pad.x,
		        inner_bottom - inner_top  - 2.0 * pad.y)
	)

# ═══════════════════════════════════════════════════════════════
#  Shop placement (inside the building)
# ═══════════════════════════════════════════════════════════════

func _place_shops(rng: RandomNumberGenerator) -> void:
	# ShopsLayer sits above BuildingArea (added after it) so shop sprites
	# draw on top of the building background.
	var shops_layer := Node2D.new()
	shops_layer.name = "ShopsLayer"
	add_child(shops_layer)

	var inner_rect := _building_area.get_inner_rect()
	# Shrink the rect so shop sprites never touch the building edge.
	var placement_margin := GameConfig.SHOP_INNER_MARGIN + GameConfig.SHOP_VISUAL_SIZE.x * 0.5
	var placement_rect   := inner_rect.grow(-placement_margin)

	var placed_positions: Array[Vector2] = []
	var placements: Array = []

	for shop_id: StringName in GameConfig.SHOP_CELL_INDICES:
		var cell_index: int = GameConfig.SHOP_CELL_INDICES[shop_id]
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

## Pick a random centre position for a shop inside `placement_rect`, keeping at
## least SHOP_MIN_SEPARATION from every already-placed shop.
## Falls back to a deterministic grid slot after SHOP_PLACEMENT_MAX_ATTEMPTS failures.
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

	# Deterministic fallback: spread shops on a 3-column grid inside the rect.
	push_warning("LoopBoard: max placement attempts reached for shop %d — using grid fallback" % placed.size())
	var cols        := 3
	var col         := placed.size() % cols
	var row         := placed.size() / cols
	var step_x      := placement_rect.size.x / cols
	var step_y      := maxf(placement_rect.size.y / 2.0, GameConfig.SHOP_MIN_SEPARATION)
	return (placement_rect.position
		+ Vector2(col * step_x + step_x * 0.5, row * step_y + step_y * 0.5)
	).clamp(placement_rect.position, placement_rect.end)

# ═══════════════════════════════════════════════════════════════
#  Validation
# ═══════════════════════════════════════════════════════════════

func _validate_shop_indices() -> void:
	var seen: Dictionary = {}
	for sid: StringName in GameConfig.SHOP_CELL_INDICES:
		var idx: int = GameConfig.SHOP_CELL_INDICES[sid]
		if idx < 0 or idx >= GameConfig.LOOP_CELL_COUNT:
			push_error("LoopBoard: shop '%s' anchor index %d is outside [0, %d)" % [
				sid, idx, GameConfig.LOOP_CELL_COUNT
			])
		if seen.has(idx):
			push_error("LoopBoard: duplicate anchor cell %d for shops '%s' and '%s'" % [
				idx, seen[idx], sid
			])
		seen[idx] = sid

# ═══════════════════════════════════════════════════════════════
#  Edge query (used by ShopMarker for tether orientation)
# ═══════════════════════════════════════════════════════════════

## Returns which edge of the loop a given cell index sits on.
func get_cell_grid_edge(index: int) -> StringName:
	if index < GameConfig.LOOP_TOP_COUNT:
		return &"top"
	elif index < GameConfig.LOOP_TOP_COUNT + GameConfig.LOOP_RIGHT_COUNT:
		return &"right"
	elif index < GameConfig.LOOP_TOP_COUNT + GameConfig.LOOP_RIGHT_COUNT + GameConfig.LOOP_BOTTOM_COUNT:
		return &"bottom"
	else:
		return &"left"

# ═══════════════════════════════════════════════════════════════
#  Lookup helpers
# ═══════════════════════════════════════════════════════════════

func get_cell(idx: int) -> PavementCell:
	if idx >= 0 and idx < _cells.size():
		return _cells[idx]
	return null

func get_cell_count() -> int:
	return _cells.size()

## Returns the ShopMarker whose anchor is `index`, or null if none.
func get_shop_marker_at_cell(index: int) -> ShopMarker:
	return _shop_markers.get(index, null)

## True when a shop marker is anchored to cell `index`.
func has_shop_at_cell(index: int) -> bool:
	return _shop_markers.has(index)
