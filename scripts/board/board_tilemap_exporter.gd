## Converts a TileMapLayer (authored in the Godot editor) into a
## BoardGraph resource suitable for gameplay.
##
## The exporter reads tile custom data to build BoardNode / Intersection
## instances, infers intra-street adjacency automatically, and uses
## manual cross_targets annotations for cross-street / intersection
## connections.
##
## Usage:
##   var exporter := BoardTilemapExporter.new()
##   var graph := exporter.export_from_layer(cells_layer, buildings_layer)
##   ResourceSaver.save(graph, "res://data/boards/my_board.tres")
##
## The TileMap is the VISUAL AUTHORING layer.  The resulting BoardGraph
## is the GAMEPLAY LOGIC layer — the TileMap is never read at runtime.
class_name BoardTilemapExporter
extends RefCounted

## Orthogonal neighbor offsets (right, down, left, up).
const _NEIGHBORS := [
	Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, 0), Vector2i(0, -1),
]

## Optional: override start node id.  If empty, uses the first node
## from the first street's even side.
var start_node_override: StringName = &""

## Optional intersection rule set.  If null, a default rule set
## (all 4 transitions enabled) is used to auto-generate Intersection
## nodes at street ends after Phase 4.
var intersection_rules: StreetIntersectionRuleSet = null

## Intermediate structures filled during export phases.
var _coord_to_id: Dictionary = {}   # Vector2i → StringName
var _id_to_coord: Dictionary = {}   # StringName → Vector2i
var _nodes: Dictionary = {}         # StringName → BoardNode
var _street_groups: Dictionary = {}  # street_id → { 0: [...ids], 1: [...ids] }

# ─────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────

## Run the full export pipeline.  Returns a ready-to-save BoardGraph.
func export_from_layer(
	cells_layer: TileMapLayer,
	buildings_layer: TileMapLayer = null
) -> BoardGraph:
	_reset()

	_phase1_collect(cells_layer)
	_phase2_intra_street_edges()
	_phase3_cross_street_edges(cells_layer)
	_phase4_build_streets()
	var graph := _phase5_assemble(buildings_layer)
	_phase6_street_end_intersections(graph)

	return graph

# ─────────────────────────────────────────────────────────────
#  Phase 1 — Collect cells
# ─────────────────────────────────────────────────────────────

func _phase1_collect(layer: TileMapLayer) -> void:
	for coord: Vector2i in layer.get_used_cells():
		var data := layer.get_cell_tile_data(coord)
		if data == null:
			continue

		var ct: int = data.get_custom_data("cell_type")
		if ct == BoardTilesetBuilder.CellType.BUILDING:
			continue

		var node_id := _coord_to_node_id(coord)
		var node: BoardNode

		if ct == BoardTilesetBuilder.CellType.INTERSECTION:
			var inter := Intersection.new()
			inter.choice_count = 0
			node = inter
		else:
			node = BoardNode.new()

		node.id = node_id
		node.position = Vector2(coord) * Vector2(GameConfig.CELL_SIZE)
		node.street_id = StringName(
			data.get_custom_data("street_id") as String
		)
		node.side = 1 if ct == BoardTilesetBuilder.CellType.PAVEMENT_ODD else 0
		node.shop_id = StringName(
			data.get_custom_data("shop_id") as String
		)

		_coord_to_id[coord] = node_id
		_id_to_coord[node_id] = coord
		_nodes[node_id] = node

		if node.street_id != &"":
			if not _street_groups.has(node.street_id):
				_street_groups[node.street_id] = { 0: [], 1: [] }
			_street_groups[node.street_id][node.side].append(node_id)

# ─────────────────────────────────────────────────────────────
#  Phase 2 — Auto-infer intra-street edges
# ─────────────────────────────────────────────────────────────

func _phase2_intra_street_edges() -> void:
	for street_id: StringName in _street_groups:
		for side: int in [0, 1]:
			var ids: Array = _street_groups[street_id][side]
			if ids.size() < 2:
				continue

			var sorted := _sort_ids_by_traversal(ids, side)
			_street_groups[street_id][side] = sorted

			for i in range(sorted.size() - 1):
				var from_id: StringName = sorted[i]
				var to_id: StringName = sorted[i + 1]
				var from_node: BoardNode = _nodes[from_id]
				if not from_node.next_nodes.has(to_id):
					from_node.next_nodes.append(to_id)

## Sort node IDs along a street into a chain using adjacency.
## Even side (0): left-to-right or top-to-bottom.
## Odd side (1): reverse direction.
func _sort_ids_by_traversal(
	ids: Array, side: int
) -> Array:
	if ids.size() <= 1:
		return ids

	var coords: Array[Vector2i] = []
	for nid in ids:
		coords.append(_id_to_coord[nid] as Vector2i)

	var min_c := coords[0]
	var max_c := coords[0]
	for c: Vector2i in coords:
		min_c.x = mini(min_c.x, c.x)
		min_c.y = mini(min_c.y, c.y)
		max_c.x = maxi(max_c.x, c.x)
		max_c.y = maxi(max_c.y, c.y)

	var is_horizontal := (max_c.x - min_c.x) >= (max_c.y - min_c.y)

	var adj := _build_adjacency_map(ids)

	var endpoints: Array = []
	for nid in ids:
		if (adj[nid] as Array).size() <= 1:
			endpoints.append(nid)

	if endpoints.is_empty():
		endpoints = [ids[0]]

	var start_id: StringName
	if endpoints.size() >= 2:
		var c0: Vector2i = _id_to_coord[endpoints[0]]
		var c1: Vector2i = _id_to_coord[endpoints[1]]
		if is_horizontal:
			start_id = endpoints[0] if c0.x <= c1.x else endpoints[1]
		else:
			start_id = endpoints[0] if c0.y <= c1.y else endpoints[1]
	else:
		start_id = endpoints[0]

	var ordered := _walk_chain(start_id, adj, ids.size())

	if side == 1:
		ordered.reverse()

	return ordered

## Build same-street/same-side adjacency (orthogonal neighbors only).
func _build_adjacency_map(ids: Array) -> Dictionary:
	var id_set := {}
	for nid in ids:
		id_set[nid] = true

	var adj := {}
	for nid in ids:
		adj[nid] = []
		var coord: Vector2i = _id_to_coord[nid]
		for off: Vector2i in _NEIGHBORS:
			var nc := coord + off
			var neighbor_id: StringName = _coord_to_id.get(nc, &"")
			if neighbor_id != &"" and id_set.has(neighbor_id):
				(adj[nid] as Array).append(neighbor_id)
	return adj

## Walk a chain from start using adjacency map.
func _walk_chain(
	start: StringName, adj: Dictionary, max_len: int
) -> Array:
	var result: Array = [start]
	var visited := { start: true }
	var current := start
	@warning_ignore("UNUSED_VARIABLE")
	for step in max_len:
		var found := false
		for neighbor: StringName in adj.get(current, []):
			if not visited.has(neighbor):
				result.append(neighbor)
				visited[neighbor] = true
				current = neighbor
				found = true
				break
		if not found:
			break
	return result

# ─────────────────────────────────────────────────────────────
#  Phase 3 — Manual cross-street edges (from cross_targets)
# ─────────────────────────────────────────────────────────────

func _phase3_cross_street_edges(layer: TileMapLayer) -> void:
	for coord: Vector2i in layer.get_used_cells():
		var data := layer.get_cell_tile_data(coord)
		if data == null:
			continue

		var ct: int = data.get_custom_data("cell_type")
		if ct == BoardTilesetBuilder.CellType.BUILDING:
			continue

		var raw: String = data.get_custom_data("cross_targets")
		if raw.strip_edges() == "":
			continue

		var from_id: StringName = _coord_to_id.get(coord, &"")
		if from_id == &"":
			continue

		var from_node: BoardNode = _nodes[from_id]
		var targets := _parse_cross_targets(raw)

		for target_coord: Vector2i in targets:
			var target_id: StringName = _coord_to_id.get(
				target_coord, &""
			)
			if target_id == &"":
				push_warning(
					"BoardTilemapExporter: cross_target %s from %s "
					+ "has no tile" % [str(target_coord), str(coord)]
				)
				continue
			if not from_node.next_nodes.has(target_id):
				from_node.next_nodes.append(target_id)

		if from_node is Intersection:
			var inter := from_node as Intersection
			inter.choice_count = from_node.next_nodes.size()
			inter.choice_destinations = from_node.next_nodes.duplicate()
			inter.choice_labels.clear()
			inter.choice_descriptions.clear()
			for i in inter.choice_count:
				inter.choice_labels.append(
					StringName("Path %d" % (i + 1))
				)
				inter.choice_descriptions.append("")

func _parse_cross_targets(raw: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var parts := raw.strip_edges().split(";")
	for part: String in parts:
		part = part.strip_edges()
		if part == "":
			continue
		var xy := part.split(",")
		if xy.size() != 2:
			push_warning(
				"BoardTilemapExporter: invalid cross_target '%s'" % part
			)
			continue
		var x := xy[0].strip_edges().to_int()
		var y := xy[1].strip_edges().to_int()
		result.append(Vector2i(x, y))
	return result

# ─────────────────────────────────────────────────────────────
#  Phase 4 — Build Street resources
# ─────────────────────────────────────────────────────────────

func _phase4_build_streets() -> void:
	pass

# ─────────────────────────────────────────────────────────────
#  Phase 5 — Assemble BoardGraph
# ─────────────────────────────────────────────────────────────

func _phase5_assemble(
	buildings_layer: TileMapLayer
) -> BoardGraph:
	var graph := BoardGraph.new()
	graph.nodes = _nodes

	for street_id: StringName in _street_groups:
		var st := Street.new()
		st.id = street_id
		st.display_name = String(street_id).capitalize()

		var even_ids: Array = _street_groups[street_id][0]
		for nid in even_ids:
			st.even_side_nodes.append(nid as StringName)

		var odd_ids: Array = _street_groups[street_id][1]
		for nid in odd_ids:
			st.odd_side_nodes.append(nid as StringName)

		var intersecting: Dictionary = {}
		for nid in even_ids:
			_collect_intersecting(nid as StringName, street_id, intersecting)
		for nid in odd_ids:
			_collect_intersecting(nid as StringName, street_id, intersecting)

		for sid: StringName in intersecting:
			st.intersecting_streets.append(sid)

		graph.streets[street_id] = st

	_assign_display_indices(graph)
	_set_start_node(graph)
	_compute_building_rect(graph, buildings_layer)

	return graph

func _collect_intersecting(
	node_id: StringName, own_street: StringName,
	out: Dictionary
) -> void:
	var node: BoardNode = _nodes.get(node_id, null)
	if node == null:
		return
	for next_id: StringName in node.next_nodes:
		var next_node: BoardNode = _nodes.get(next_id, null)
		if next_node == null:
			continue
		if next_node.street_id != &"" and next_node.street_id != own_street:
			out[next_node.street_id] = true

func _assign_display_indices(graph: BoardGraph) -> void:
	var idx := 1
	for street_id: StringName in _street_groups:
		for side: int in [0, 1]:
			var ids: Array = _street_groups[street_id][side]
			for nid in ids:
				var node: BoardNode = graph.nodes.get(nid, null)
				if node:
					node.display_index = idx
					idx += 1

func _set_start_node(graph: BoardGraph) -> void:
	if start_node_override != &"":
		graph.start_node_id = start_node_override
		return

	for street_id: StringName in _street_groups:
		var even_ids: Array = _street_groups[street_id][0]
		if not even_ids.is_empty():
			graph.start_node_id = even_ids[0] as StringName
			return

	if not _nodes.is_empty():
		for nid: StringName in _nodes:
			graph.start_node_id = nid
			return

func _compute_building_rect(
	graph: BoardGraph, buildings_layer: TileMapLayer
) -> void:
	if buildings_layer == null:
		graph.building_rect = Rect2()
		return

	var cells := buildings_layer.get_used_cells()
	if cells.is_empty():
		graph.building_rect = Rect2()
		return

	var min_c: Vector2i = cells[0]
	var max_c: Vector2i = cells[0]
	for c: Vector2i in cells:
		min_c.x = mini(min_c.x, c.x)
		min_c.y = mini(min_c.y, c.y)
		max_c.x = maxi(max_c.x, c.x)
		max_c.y = maxi(max_c.y, c.y)

	var cs := GameConfig.CELL_SIZE
	graph.building_rect = Rect2(
		Vector2(min_c) * cs,
		Vector2(max_c - min_c + Vector2i.ONE) * cs
	)

# ─────────────────────────────────────────────────────────────
#  Phase 6 — Auto-generate Intersection nodes at street ends
# ─────────────────────────────────────────────────────────────

func _phase6_street_end_intersections(graph: BoardGraph) -> void:
	var rules := intersection_rules if intersection_rules else StreetIntersectionRuleSet.new()
	var builder := StreetEndIntersectionBuilder.new()
	builder.build_intersections(graph, rules)

# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────

func _reset() -> void:
	_coord_to_id.clear()
	_id_to_coord.clear()
	_nodes.clear()
	_street_groups.clear()

static func _coord_to_node_id(coord: Vector2i) -> StringName:
	return StringName("cell_%d_%d" % [coord.x, coord.y])
