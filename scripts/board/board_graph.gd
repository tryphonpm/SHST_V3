## Directed graph of BoardNode instances describing the full board topology.
## Serialisable as a .tres Resource for easy editing and alternative layouts.
##
## All runtime movement, lap detection, and shop lookup go through this class.
## The old int-index based movement is replaced by StringName node-ID traversal.
##
## TODO: will support Paris-district topology and graph-based routing.
## TODO: serialise/deserialise to .tres for hand-authored layouts.
class_name BoardGraph
extends Resource

## All nodes keyed by their unique id.
@export var nodes: Dictionary = {}  # StringName → BoardNode

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

## Returns the BoardNode instances reachable in one step from `node_id`.
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
## For simple loops this is the only choice; intersections will need a
## player choice UI.
## TODO: when multiple next_nodes exist, prompt the player to choose direction.
func get_default_next(node_id: StringName) -> StringName:
	var node := get_node_by_id(node_id)
	if node == null or node.next_nodes.is_empty():
		push_warning("BoardGraph: node '%s' has no outgoing edges" % node_id)
		return node_id  # stay put
	return node.next_nodes[0]

func is_start_node(node_id: StringName) -> bool:
	return node_id == start_node_id

## True if the node is an Intersection (has multiple outgoing edges and
## requires a player choice before movement can continue).
func is_intersection(node_id: StringName) -> bool:
	var node := get_node_by_id(node_id)
	return node is Intersection

# ─────────────────────────────────────────────────────────────
#  Spatial queries
# ─────────────────────────────────────────────────────────────

## Find the node whose position is closest to `pos` within `threshold` pixels.
func find_node_by_position(pos: Vector2, threshold: float = 48.0) -> BoardNode:
	var best: BoardNode = null
	var best_dist := threshold
	for id: StringName in nodes:
		var n: BoardNode = nodes[id]
		var d := n.position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = n
	return best

## Axis-aligned bounding rect of all node positions (with half-cell padding).
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
			min_pos = Vector2(minf(min_pos.x, p.x), minf(min_pos.y, p.y))
			max_pos = Vector2(maxf(max_pos.x, p.x), maxf(max_pos.y, p.y))
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
#  Path computation
# ─────────────────────────────────────────────────────────────

## Walk `steps` edges forward from `from_id`, returning the ordered list of
## visited node IDs (excluding the starting node).
## Uses get_default_next() at each step (first outgoing edge).
func compute_path(from_id: StringName, steps: int) -> Array[StringName]:
	var path: Array[StringName] = []
	var pos := from_id
	for _i in steps:
		pos = get_default_next(pos)
		path.append(pos)
	return path

# ─────────────────────────────────────────────────────────────
#  Ordered iteration (for building visual cells in draw order)
# ─────────────────────────────────────────────────────────────

## Walk the graph from start_node_id, following default edges, and return
## nodes in traversal order. Stops after visiting get_node_count() nodes
## or when it revisits the start node (whichever comes first).
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
