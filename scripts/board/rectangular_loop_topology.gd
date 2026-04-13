## 34-cell rectangular pavement loop around a central building.
## Backwards-compatible migration helper: exports its geometry as a
## BoardGraph so the rest of the system uses the new graph-based
## movement.
##
## Street-side model (backward compat):
##   The rectangular loop is represented as a SINGLE Street
##   (&"loop") whose even_side_nodes contain all 34 cells in
##   clockwise order.  odd_side_nodes is empty because the loop
##   has only one walking direction.  All nodes get side == 0 and
##   street_id == &"loop".
##
## TODO: will support Paris-district topology and graph-based
##       routing with real multi-street layouts.
class_name RectangularLoopTopology
extends BoardTopology

# ─────────────────────────────────────────────────────────────
#  BoardTopology override
# ─────────────────────────────────────────────────────────────

func build_graph() -> BoardGraph:
	var graph := BoardGraph.new()
	graph.start_node_id = GameConfig.LOOP_START_NODE

	var positions := _build_loop_positions()
	assert(
		positions.size() == GameConfig.LOOP_CELL_COUNT,
		"RectangularLoopTopology: expected %d positions, got %d"
		% [GameConfig.LOOP_CELL_COUNT, positions.size()]
	)

	var shop_cells := GameConfig.SHOP_CELL_INDICES
	var all_ids: Array[StringName] = []

	for i in positions.size():
		var node := BoardNode.new()
		node.id            = _id_for_index(i)
		node.position      = positions[i]
		node.street_id     = GameConfig.LOOP_STREET_ID
		node.side          = 0
		node.display_index = i + 1
		node.next_nodes    = [
			_id_for_index((i + 1) % positions.size())
		]

		for sid: StringName in shop_cells:
			if shop_cells[sid] == i:
				node.shop_id = sid
				break

		graph.nodes[node.id] = node
		all_ids.append(node.id)

	# Register the single backward-compat street.
	var loop_street := Street.new()
	loop_street.id               = GameConfig.LOOP_STREET_ID
	loop_street.display_name     = "Loop"
	loop_street.even_side_nodes  = all_ids
	loop_street.odd_side_nodes   = []
	loop_street.intersecting_streets = []
	graph.streets[loop_street.id] = loop_street

	graph.building_rect = _compute_inner_rect()
	return graph

# ─────────────────────────────────────────────────────────────
#  Geometry helpers
# ─────────────────────────────────────────────────────────────

static func _id_for_index(index: int) -> StringName:
	return StringName("cell_%d" % index)

func _build_loop_positions() -> Array[Vector2]:
	var pos: Array[Vector2] = []
	var cs := GameConfig.CELL_SIZE

	for i in GameConfig.LOOP_TOP_COUNT:
		pos.append(Vector2(i * cs.x, 0.0))

	var right_x := (GameConfig.LOOP_TOP_COUNT - 1) * cs.x
	for i in GameConfig.LOOP_RIGHT_COUNT:
		pos.append(Vector2(right_x, (i + 1) * cs.y))

	var bottom_y := GameConfig.LOOP_RIGHT_COUNT * cs.y
	for i in GameConfig.LOOP_BOTTOM_COUNT:
		pos.append(Vector2(
			(GameConfig.LOOP_TOP_COUNT - 2 - i) * cs.x,
			bottom_y
		))

	for i in GameConfig.LOOP_LEFT_COUNT:
		pos.append(Vector2(
			0.0,
			(GameConfig.LOOP_RIGHT_COUNT - 1 - i) * cs.y
		))

	if pos.size() == GameConfig.LOOP_CELL_COUNT:
		var gap := pos[GameConfig.LOOP_END_INDEX].distance_to(
			pos[GameConfig.LOOP_START_INDEX]
		)
		assert(
			is_equal_approx(gap, cs.x) \
			or is_equal_approx(gap, cs.y),
			"Loop does not close — gap is %.1fpx" % gap
		)
	return pos

func _compute_inner_rect() -> Rect2:
	var cs  := GameConfig.CELL_SIZE
	var pad := GameConfig.BUILDING_INNER_PADDING

	var inner_left   := cs.x * 0.5
	var inner_top    := cs.y * 0.5
	var inner_right  := (
		(GameConfig.LOOP_TOP_COUNT - 1) * cs.x - cs.x * 0.5
	)
	var inner_bottom := (
		GameConfig.LOOP_RIGHT_COUNT * cs.y - cs.y * 0.5
	)

	return Rect2(
		Vector2(inner_left + pad.x, inner_top + pad.y),
		Vector2(
			inner_right  - inner_left  - 2.0 * pad.x,
			inner_bottom - inner_top   - 2.0 * pad.y
		)
	)
