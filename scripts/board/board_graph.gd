## Directed graph of BoardNode instances describing the full board topology.
## Serialisable as a .tres Resource for easy editing and alternative layouts.
##
## All runtime movement, lap detection, and shop lookup go through this
## class.  The old int-index based movement is replaced by StringName
## node-ID traversal.
##
## Persistence:
##   Use save_to_file() / load_from_file() to round-trip via .tres.
##   ParisDistrictTopology.build_and_save() generates the canonical
##   paris_district_v1.tres file.  BoardGame loads it at startup.
##
## Street-side model (Parisian pavements):
##   Each street has two directional sidewalks stored in Street.gd.
##   Same side parity  = same physical walking direction.
##   Opposite parity   = reverse physical walking direction.
##   Transitions at street ends are encoded as Intersection nodes by the
##   topology builder — see Street.gd for the full rule set.
class_name BoardGraph
extends Resource

## All nodes keyed by their unique id.
@export var nodes: Dictionary = {}  # StringName → BoardNode

## All streets keyed by their unique id.
@export var streets: Dictionary = {}  # StringName → Street

## The node where every player starts and where laps are counted.
@export var start_node_id: StringName = &""

## Building interior rect (for shop marker placement). Rect2() if none.
@export var building_rect: Rect2 = Rect2()

# ─────────────────────────────────────────────────────────────
#  Node queries
# ─────────────────────────────────────────────────────────────

func get_node_by_id(id: StringName) -> BoardNode:
	return nodes.get(id, null)

func get_node_count() -> int:
	return nodes.size()

## Returns the BoardNode instances reachable in one step from
## `node_id`.
func get_next_nodes(node_id: StringName) -> Array[BoardNode]:
	var node := get_node_by_id(node_id)
	if node == null:
		return []
	var result: Array[BoardNode] = []
	for nid: StringName in node.next_nodes:
		var n := get_node_by_id(nid)
		if n:
			result.append(n)
	return result

## Default forward direction: returns the first entry in next_nodes.
## For simple loops this is the only choice; intersections will need
## a player choice UI.
func get_default_next(node_id: StringName) -> StringName:
	var node := get_node_by_id(node_id)
	if node == null or node.next_nodes.is_empty():
		push_warning(
			"BoardGraph: node '%s' has no outgoing edges" % node_id
		)
		return node_id
	return node.next_nodes[0]

func is_start_node(node_id: StringName) -> bool:
	return node_id == start_node_id

## True if the node is an Intersection (has multiple outgoing edges
## and requires a player choice before movement can continue).
func is_intersection(node_id: StringName) -> bool:
	var node := get_node_by_id(node_id)
	return node is Intersection

# ─────────────────────────────────────────────────────────────
#  Street queries
# ─────────────────────────────────────────────────────────────

## Return the Street that owns `node_id`, or null if the node doesn't
## belong to any registered street.
func get_street_at_node(node_id: StringName) -> Street:
	var node := get_node_by_id(node_id)
	if node == null or node.street_id == &"":
		return null
	return streets.get(node.street_id, null)

## Return the Street resource by its id, or null.
func get_street(street_id: StringName) -> Street:
	return streets.get(street_id, null)

## Walking direction for the node on its street:
##   +1 = forward  (even side, side == 0)
##   -1 = reverse  (odd side,  side == 1)
##    0 = unknown  (node has no street / side data)
func get_walking_direction(node_id: StringName) -> int:
	var node := get_node_by_id(node_id)
	if node == null:
		return 0
	if node.side == 0:
		return 1
	if node.side == 1:
		return -1
	return 0

## True when the node is the LAST node on its side of its street
## (i.e. the player is about to leave that sidewalk and will face
## a transition choice — turn, cross, etc.).
func is_street_end(node_id: StringName) -> bool:
	var st := get_street_at_node(node_id)
	if st == null:
		return false
	var node := get_node_by_id(node_id)
	if node == null:
		return false
	return node_id == st.get_exit_node(node.side)

## True when the node is the FIRST node on its side of its street
## (i.e. the player just entered this sidewalk).
func is_street_entry(node_id: StringName) -> bool:
	var st := get_street_at_node(node_id)
	if st == null:
		return false
	var node := get_node_by_id(node_id)
	if node == null:
		return false
	return node_id == st.get_entry_node(node.side)

# ─────────────────────────────────────────────────────────────
#  Spatial queries
# ─────────────────────────────────────────────────────────────

## Find the node whose position is closest to `pos` within
## `threshold` pixels.
func find_node_by_position(
	pos: Vector2, threshold: float = 48.0
) -> BoardNode:
	var best: BoardNode = null
	var best_dist := threshold
	for id: StringName in nodes:
		var n: BoardNode = nodes[id]
		var d := n.position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = n
	return best

## Axis-aligned bounding rect of all node positions (with half-cell
## padding).
func get_bounding_rect() -> Rect2:
	if nodes.is_empty():
		return Rect2()
	var cs := GameConfig.CELL_SIZE
	var first := true
	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO
	for id: StringName in nodes:
		var p: Vector2 = (nodes[id] as BoardNode).position
		if first:
			min_pos = p
			max_pos = p
			first = false
		else:
			min_pos.x = minf(min_pos.x, p.x)
			min_pos.y = minf(min_pos.y, p.y)
			max_pos.x = maxf(max_pos.x, p.x)
			max_pos.y = maxf(max_pos.y, p.y)
	return Rect2(min_pos - cs * 0.5, max_pos - min_pos + cs)

# ─────────────────────────────────────────────────────────────
#  Shop queries
# ─────────────────────────────────────────────────────────────

## Returns the shop_id at `node_id`, or &"" if none.
func get_shop_at(node_id: StringName) -> StringName:
	var node := get_node_by_id(node_id)
	if node:
		return node.shop_id
	return &""

## Returns the node ID that anchors `shop_id`, or &"" if not found.
func find_shop_node_id(shop_id: StringName) -> StringName:
	for id: StringName in nodes:
		var n: BoardNode = nodes[id]
		if n.shop_id == shop_id:
			return id
	return &""

# ─────────────────────────────────────────────────────────────
#  Street-end intersection generation
# ─────────────────────────────────────────────────────────────

## Scan all streets for end nodes and replace them with Intersection
## nodes offering the Parisian transition choices.  Call after streets
## are populated but before the graph is used for gameplay.
func generate_street_end_intersections(
	rules: StreetIntersectionRuleSet = null
) -> void:
	var builder := StreetEndIntersectionBuilder.new()
	builder.build_intersections(self, rules)

# ─────────────────────────────────────────────────────────────
#  Path computation
# ─────────────────────────────────────────────────────────────

## Walk `steps` edges forward from `from_id`, returning the ordered
## list of visited node IDs (excluding the starting node).
## Uses get_default_next() at each step (first outgoing edge).
func compute_path(
	from_id: StringName, steps: int
) -> Array[StringName]:
	var path: Array[StringName] = []
	var pos := from_id
	for _i in steps:
		pos = get_default_next(pos)
		path.append(pos)
	return path

# ─────────────────────────────────────────────────────────────
#  Ordered iteration (for building visual cells in draw order)
# ─────────────────────────────────────────────────────────────

## Walk the graph from start_node_id, following default edges, and
## return nodes in traversal order. Stops after visiting
## get_node_count() nodes or when it revisits the start node
## (whichever comes first).
func get_ordered_nodes() -> Array[BoardNode]:
	var ordered: Array[BoardNode] = []
	if start_node_id == &"":
		return ordered
	var current := start_node_id
	for _i in get_node_count():
		var node := get_node_by_id(current)
		if node == null:
			break
		ordered.append(node)
		current = get_default_next(current)
		if current == start_node_id:
			break
	return ordered

# ─────────────────────────────────────────────────────────────
#  Persistence
# ─────────────────────────────────────────────────────────────

## Save this graph to a .tres file.  Creates parent directories if
## needed.  Returns OK on success.
func save_to_file(path: String) -> Error:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(self, path)
	if err == OK:
		print("BoardGraph: saved to %s (%d nodes, %d streets)"
			% [path, get_node_count(), streets.size()])
	else:
		push_error("BoardGraph: save failed → %s (error %d)" % [path, err])
	return err

## Load a BoardGraph from a .tres file.  Returns null on failure.
static func load_from_file(path: String) -> BoardGraph:
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_REPLACE
	)
	if res is BoardGraph:
		return res as BoardGraph
	push_warning("BoardGraph: '%s' is not a BoardGraph resource" % path)
	return null

# ─────────────────────────────────────────────────────────────
#  Integrity verification
# ─────────────────────────────────────────────────────────────

## Structural integrity check.  Returns an array of warning strings.
## Empty array = all good.
func verify_integrity() -> Array[String]:
	var warnings: Array[String] = []
	if nodes.is_empty():
		warnings.append("Graph has no nodes")
		return warnings

	if start_node_id == &"":
		warnings.append("start_node_id is empty")
	elif not nodes.has(start_node_id):
		warnings.append(
			"start_node_id '%s' not found in nodes" % start_node_id
		)

	var shop_nodes: Dictionary = {}
	for nid: StringName in nodes:
		var node: BoardNode = nodes[nid]

		if node.id != nid:
			warnings.append(
				"Node key '%s' != node.id '%s'" % [nid, node.id]
			)

		for next_id: StringName in node.next_nodes:
			if not nodes.has(next_id):
				warnings.append(
					"Node '%s' references missing next '%s'"
					% [nid, next_id]
				)

		if node is Intersection:
			var inter := node as Intersection
			if not inter.validate():
				warnings.append(
					"Intersection '%s' failed validate()" % nid
				)

		if node.shop_id != &"":
			if shop_nodes.has(node.shop_id):
				warnings.append(
					"Duplicate shop_id '%s' on '%s' and '%s'"
					% [node.shop_id, shop_nodes[node.shop_id], nid]
				)
			shop_nodes[node.shop_id] = nid

		if node.street_id != &"" and not streets.has(node.street_id):
			warnings.append(
				"Node '%s' street_id '%s' not in streets dict"
				% [nid, node.street_id]
			)

	for sid: StringName in streets:
		var st: Street = streets[sid]
		for eid: StringName in st.even_side_nodes:
			if not nodes.has(eid):
				warnings.append(
					"Street '%s' even node '%s' missing" % [sid, eid]
				)
		for oid: StringName in st.odd_side_nodes:
			if not nodes.has(oid):
				warnings.append(
					"Street '%s' odd node '%s' missing" % [sid, oid]
				)

	return warnings

## Full round-trip verification: save → reload → walk graph → check
## shops → check node IDs.  Returns issues (empty = success).
## Cleans up the temp file afterwards.
static func verify_round_trip(original: BoardGraph) -> Array[String]:
	var issues: Array[String] = []

	var pre := original.verify_integrity()
	if not pre.is_empty():
		issues.append("PRE-SAVE integrity issues:")
		issues.append_array(pre)

	var tmp_path := "res://data/boards/_roundtrip_verify.tres"
	var err := original.save_to_file(tmp_path)
	if err != OK:
		issues.append("Save failed with error %d" % err)
		return issues

	var loaded := BoardGraph.load_from_file(tmp_path)
	if loaded == null:
		issues.append("Reload returned null")
		DirAccess.remove_absolute(tmp_path)
		return issues

	if loaded.get_node_count() != original.get_node_count():
		issues.append(
			"Node count: original %d, loaded %d"
			% [original.get_node_count(), loaded.get_node_count()]
		)
	if loaded.streets.size() != original.streets.size():
		issues.append(
			"Street count: original %d, loaded %d"
			% [original.streets.size(), loaded.streets.size()]
		)
	if loaded.start_node_id != original.start_node_id:
		issues.append(
			"start_node_id: original '%s', loaded '%s'"
			% [original.start_node_id, loaded.start_node_id]
		)

	for nid: StringName in original.nodes:
		if not loaded.nodes.has(nid):
			issues.append("Missing node '%s' after reload" % nid)
			continue
		var orig_node: BoardNode = original.nodes[nid]
		var load_node: BoardNode = loaded.nodes[nid]
		if orig_node.position.distance_to(load_node.position) > 0.01:
			issues.append(
				"Node '%s' position drift: %s → %s"
				% [nid, orig_node.position, load_node.position]
			)
		if orig_node.shop_id != load_node.shop_id:
			issues.append(
				"Node '%s' shop_id: '%s' → '%s'"
				% [nid, orig_node.shop_id, load_node.shop_id]
			)
		if orig_node.next_nodes.size() != load_node.next_nodes.size():
			issues.append(
				"Node '%s' next_nodes count: %d → %d"
				% [nid, orig_node.next_nodes.size(),
				   load_node.next_nodes.size()]
			)
		if (orig_node is Intersection) != (load_node is Intersection):
			issues.append(
				"Node '%s' type mismatch: Intersection=%s → %s"
				% [nid, orig_node is Intersection,
				   load_node is Intersection]
			)

	for nid: StringName in loaded.nodes:
		var node: BoardNode = loaded.nodes[nid]
		if node.shop_id != &"":
			var found := loaded.find_shop_node_id(node.shop_id)
			if found != nid:
				issues.append(
					"Shop '%s' lookup returned '%s', expected '%s'"
					% [node.shop_id, found, nid]
				)

	var walked: Dictionary = {}
	var cursor := loaded.start_node_id
	for _i in loaded.get_node_count() + 10:
		if walked.has(cursor):
			break
		walked[cursor] = true
		var wn := loaded.get_node_by_id(cursor)
		if wn == null:
			issues.append("Walk hit missing node '%s'" % cursor)
			break
		if wn.next_nodes.is_empty():
			break
		cursor = wn.next_nodes[0]
	if walked.is_empty():
		issues.append("Graph walk visited 0 nodes")

	var post := loaded.verify_integrity()
	if not post.is_empty():
		issues.append("POST-LOAD integrity issues:")
		issues.append_array(post)

	DirAccess.remove_absolute(tmp_path)

	_print_verify_summary(
		"Round-trip", loaded, issues, walked.size()
	)
	return issues

static func _print_verify_summary(
	label: String, graph: BoardGraph,
	issues: Array[String], walked: int
) -> void:
	var inter_count := 0
	var shop_count := 0
	for nid: StringName in graph.nodes:
		var node: BoardNode = graph.nodes[nid]
		if node is Intersection:
			inter_count += 1
		if node.shop_id != &"":
			shop_count += 1

	print("=== BoardGraph %s Verify ===" % label)
	print("  Nodes: %d (intersections: %d, shops: %d)"
		% [graph.get_node_count(), inter_count, shop_count])
	print("  Streets: %d" % graph.streets.size())
	print("  Start: %s" % graph.start_node_id)
	print("  Walk reached: %d nodes" % walked)
	if issues.is_empty():
		print("  ALL OK")
	else:
		for issue in issues:
			push_warning("  %s" % issue)
	print("===================================")
