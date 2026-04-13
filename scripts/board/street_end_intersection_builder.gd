## Detects street-end nodes in a BoardGraph and replaces them with
## Intersection nodes offering the Parisian transition choices defined
## in a StreetIntersectionRuleSet.
##
## Call build_intersections() after streets are populated in the graph.
## The builder:
##   1. Determines each street's orientation (horizontal / vertical)
##      from the bounding box of its node positions.
##   2. For every street-end node (exit of even side, exit of odd side)
##      computes which of the 4 transition rules are valid by looking
##      for parallel / perpendicular / opposite-side streets in the
##      graph.
##   3. Replaces the street-end BoardNode with an Intersection whose
##      choices are only the valid transitions.
class_name StreetEndIntersectionBuilder
extends RefCounted

## Walking direction vectors per orientation + side.
## Orientation 0 = horizontal, 1 = vertical.
## Side 0 = even (forward), side 1 = odd (reverse).
const _WALK_DIRS: Dictionary = {
	# horizontal even: left → right
	Vector2i(0, 0): Vector2(1, 0),
	# horizontal odd: right → left
	Vector2i(0, 1): Vector2(-1, 0),
	# vertical even: top → bottom
	Vector2i(1, 0): Vector2(0, 1),
	# vertical odd: bottom → top
	Vector2i(1, 1): Vector2(0, -1),
}

var _rules: StreetIntersectionRuleSet
var _graph: BoardGraph

## Cached orientation per street id: 0 = horizontal, 1 = vertical.
var _orientations: Dictionary = {}

## Cached centroid per street id.
var _centroids: Dictionary = {}

# ─────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────

## Mutates `graph` in place, inserting Intersection nodes at every
## street-end that has at least 2 valid transition choices.
func build_intersections(
	graph: BoardGraph,
	rules: StreetIntersectionRuleSet = null
) -> void:
	_graph = graph
	_rules = rules if rules else StreetIntersectionRuleSet.new()
	_compute_street_metadata()

	var to_replace: Array[Dictionary] = []

	for street_id: StringName in graph.streets:
		var st: Street = graph.streets[street_id]
		for p_side: int in [0, 1]:
			var exit_id := st.get_exit_node(p_side)
			if exit_id == &"":
				continue
			var node := graph.get_node_by_id(exit_id)
			if node == null or node is Intersection:
				continue
			var choices := _compute_choices(st, p_side, node)
			if choices.size() < 2:
				continue
			to_replace.append({
				"node": node,
				"street": st,
				"side": p_side,
				"choices": choices,
			})

	for entry: Dictionary in to_replace:
		_replace_with_intersection(entry)

# ─────────────────────────────────────────────────────────────
#  Street metadata
# ─────────────────────────────────────────────────────────────

func _compute_street_metadata() -> void:
	_orientations.clear()
	_centroids.clear()
	for street_id: StringName in _graph.streets:
		var st: Street = _graph.streets[street_id]
		_orientations[street_id] = _orientation_of(st)
		_centroids[street_id] = _centroid_of(st)

## 0 = horizontal (wider than tall), 1 = vertical.
func _orientation_of(st: Street) -> int:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for nid: StringName in st.even_side_nodes:
		var n := _graph.get_node_by_id(nid)
		if n:
			min_pos = min_pos.min(n.position)
			max_pos = max_pos.max(n.position)
	for nid: StringName in st.odd_side_nodes:
		var n := _graph.get_node_by_id(nid)
		if n:
			min_pos = min_pos.min(n.position)
			max_pos = max_pos.max(n.position)
	var span := max_pos - min_pos
	return 0 if span.x >= span.y else 1

func _centroid_of(st: Street) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for nid: StringName in st.even_side_nodes:
		var n := _graph.get_node_by_id(nid)
		if n:
			sum += n.position
			count += 1
	for nid: StringName in st.odd_side_nodes:
		var n := _graph.get_node_by_id(nid)
		if n:
			sum += n.position
			count += 1
	if count == 0:
		return Vector2.ZERO
	return sum / float(count)

## Walking direction unit vector for a given street + side.
func _walk_direction(street_id: StringName, p_side: int) -> Vector2:
	var ori: int = _orientations.get(street_id, 0)
	return _WALK_DIRS.get(Vector2i(ori, p_side), Vector2.RIGHT)

# ─────────────────────────────────────────────────────────────
#  Choice computation
# ─────────────────────────────────────────────────────────────

## Returns an array of { key, label, dest_id, description, arrow }
## for each valid transition at a street-end node.
func _compute_choices(
	st: Street, p_side: int, end_node: BoardNode
) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var walk_dir := _walk_direction(st.id, p_side)

	if _rules.allow_left_turn:
		var dest := _find_left_turn(st, p_side, end_node, walk_dir)
		if dest != &"":
			choices.append(_choice_entry(
				StreetIntersectionRuleSet.KEY_LEFT_TURN, dest
			))

	if _rules.allow_straight_cross:
		var dest := _find_straight_cross(st, p_side, end_node, walk_dir)
		if dest != &"":
			choices.append(_choice_entry(
				StreetIntersectionRuleSet.KEY_STRAIGHT_CROSS, dest
			))

	if _rules.allow_opposite_side:
		var dest := _find_opposite_side(st, p_side)
		if dest != &"":
			choices.append(_choice_entry(
				StreetIntersectionRuleSet.KEY_OPPOSITE_SIDE, dest
			))

	if _rules.allow_right_turn:
		var dest := _find_right_turn(st, p_side, end_node, walk_dir)
		if dest != &"":
			choices.append(_choice_entry(
				StreetIntersectionRuleSet.KEY_RIGHT_TURN, dest
			))

	return choices

func _choice_entry(
	key: StringName, dest_id: StringName
) -> Dictionary:
	return {
		"key": key,
		"label": StreetIntersectionRuleSet.get_display_label(key),
		"arrow": StreetIntersectionRuleSet.get_arrow(key),
		"dest_id": dest_id,
		"description": StreetIntersectionRuleSet.get_description(key),
	}

# ─────────────────────────────────────────────────────────────
#  Rule implementations
# ─────────────────────────────────────────────────────────────

## Left turn: parallel street to the left, same side parity.
## "Left" = perpendicular to walk direction, on the left-hand side.
func _find_left_turn(
	st: Street, p_side: int,
	end_node: BoardNode, walk_dir: Vector2
) -> StringName:
	var left_dir := Vector2(-walk_dir.y, walk_dir.x)
	return _find_parallel_street_in_direction(
		st, p_side, end_node, left_dir
	)

## Right turn: perpendicular street to the right.
func _find_right_turn(
	st: Street, p_side: int,
	end_node: BoardNode, walk_dir: Vector2
) -> StringName:
	var right_dir := Vector2(walk_dir.y, -walk_dir.x)
	return _find_perpendicular_street_entry(
		st, p_side, end_node, walk_dir, right_dir
	)

## Straight cross: continue on same street, next block, same side.
## Requires multi-block streets (street has been split into blocks).
## For now, looks for another street with the same orientation whose
## entry node is roughly one cell ahead of the exit node.
func _find_straight_cross(
	st: Street, p_side: int,
	end_node: BoardNode, walk_dir: Vector2
) -> StringName:
	var ahead_pos := end_node.position + walk_dir * GameConfig.CELL_SIZE.x
	var threshold := _rules.neighbor_block_distance * GameConfig.CELL_SIZE.x
	var my_ori: int = _orientations.get(st.id, 0)

	for sid: StringName in _graph.streets:
		if sid == st.id:
			continue
		var other: Street = _graph.streets[sid]
		var other_ori: int = _orientations.get(sid, 0)
		if other_ori != my_ori:
			continue
		var entry := other.get_entry_node(p_side)
		if entry == &"":
			continue
		var entry_node := _graph.get_node_by_id(entry)
		if entry_node == null:
			continue
		if entry_node.position.distance_to(ahead_pos) < threshold:
			return entry
	return &""

## Opposite side: same street, opposite parity.
## Destination = exit node of the opposite side (so the player enters
## at the end and walks back).
func _find_opposite_side(st: Street, p_side: int) -> StringName:
	var opp_side := 1 - p_side
	var opp_exit := st.get_exit_node(opp_side)
	if opp_exit == &"":
		return &""
	return opp_exit

## Find a parallel street whose centroid is in `search_dir` from the
## current street, return its entry node on the same side parity.
func _find_parallel_street_in_direction(
	st: Street, p_side: int,
	end_node: BoardNode, search_dir: Vector2
) -> StringName:
	var my_ori: int = _orientations.get(st.id, 0)
	var threshold := _rules.neighbor_block_distance * GameConfig.CELL_SIZE.x
	var best_id := &""
	var best_dist := INF

	for sid: StringName in _graph.streets:
		if sid == st.id:
			continue
		var other_ori: int = _orientations.get(sid, 0)
		if other_ori != my_ori:
			continue
		var other: Street = _graph.streets[sid]
		var entry := other.get_entry_node(p_side)
		if entry == &"":
			continue
		var entry_node := _graph.get_node_by_id(entry)
		if entry_node == null:
			continue

		var delta := entry_node.position - end_node.position
		var dot := delta.dot(search_dir)
		if dot <= 0:
			continue
		var dist := delta.length()
		if dist < threshold and dist < best_dist:
			best_dist = dist
			best_id = entry
	return best_id

## Find a perpendicular street whose entry is roughly in
## `turn_dir` from the exit node and whose orientation differs.
func _find_perpendicular_street_entry(
	st: Street, _p_side: int,
	end_node: BoardNode, _walk_dir: Vector2, turn_dir: Vector2
) -> StringName:
	var my_ori: int = _orientations.get(st.id, 0)
	var threshold := _rules.neighbor_block_distance * GameConfig.CELL_SIZE.x
	var best_id := &""
	var best_dist := INF

	for sid: StringName in _graph.streets:
		if sid == st.id:
			continue
		var other_ori: int = _orientations.get(sid, 0)
		if other_ori == my_ori:
			continue
		var other: Street = _graph.streets[sid]
		for try_side: int in [0, 1]:
			var entry := other.get_entry_node(try_side)
			if entry == &"":
				continue
			var entry_node := _graph.get_node_by_id(entry)
			if entry_node == null:
				continue

			var delta := entry_node.position - end_node.position
			var dot := delta.dot(turn_dir)
			if dot <= 0:
				continue
			var dist := delta.length()
			if dist < threshold and dist < best_dist:
				best_dist = dist
				best_id = entry
	return best_id

# ─────────────────────────────────────────────────────────────
#  Node replacement
# ─────────────────────────────────────────────────────────────

## Replace a regular BoardNode with an Intersection node carrying
## the computed choices.
func _replace_with_intersection(entry: Dictionary) -> void:
	var old_node: BoardNode = entry["node"]
	var choices: Array[Dictionary] = entry["choices"]

	var inter := Intersection.new()
	inter.id            = old_node.id
	inter.position      = old_node.position
	inter.street_id     = old_node.street_id
	inter.side          = old_node.side
	inter.shop_id       = old_node.shop_id
	inter.display_index = old_node.display_index

	inter.choice_count = choices.size()
	inter.next_nodes.clear()
	inter.choice_labels.clear()
	inter.choice_destinations.clear()
	inter.choice_descriptions.clear()

	for c: Dictionary in choices:
		var dest_id: StringName = c["dest_id"]
		var key: StringName = c["key"]
		var desc: String = c["description"]
		var arrow: String = c["arrow"]

		inter.next_nodes.append(dest_id)
		inter.choice_labels.append(
			StringName("%s %s" % [arrow, StreetIntersectionRuleSet.get_display_label(key)])
		)
		inter.choice_destinations.append(dest_id)
		inter.choice_descriptions.append(desc)

	_graph.nodes[inter.id] = inter
