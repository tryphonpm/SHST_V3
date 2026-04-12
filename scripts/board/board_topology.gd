## Abstract base class describing the spatial layout and traversal rules of a
## game board. Concrete subclasses (e.g. RectangularLoopTopology) provide the
## actual geometry; consumers (LoopBoard, TurnManager) program against this
## interface so the board shape can change without touching gameplay code.
##
## TODO: will support Paris-district topology and graph-based routing.
class_name BoardTopology
extends RefCounted

# ─────────────────────────────────────────────────────────────
#  Lightweight inner data types
# ─────────────────────────────────────────────────────────────

## One traversable cell on the board.
class BoardCell:
	var index: int
	var position: Vector2          # world-space position (LoopBoard local coords)
	var edge_name: StringName      # which logical edge (e.g. &"top", &"right")

	func _init(p_index: int = 0, p_position := Vector2.ZERO, p_edge := &"") -> void:
		index     = p_index
		position  = p_position
		edge_name = p_edge

## A directed connection between two cells.
class BoardEdge:
	var from_index: int
	var to_index: int

	func _init(p_from: int = 0, p_to: int = 0) -> void:
		from_index = p_from
		to_index   = p_to

## A cell where multiple paths branch (unused in the rectangular loop but
## necessary for future graph-based topologies like a Paris-district map).
## TODO: will support Paris-district topology and graph-based routing.
class Intersection:
	var cell_index: int
	var connected_edges: Array[BoardEdge]

	func _init(p_cell_index: int = 0, p_edges: Array[BoardEdge] = []) -> void:
		cell_index      = p_cell_index
		connected_edges = p_edges

# ─────────────────────────────────────────────────────────────
#  Graph queries — override in subclasses
# ─────────────────────────────────────────────────────────────

## All cells in traversal order.
func get_cells() -> Array[BoardCell]:
	push_error("BoardTopology.get_cells() is abstract — override in subclass")
	return []

## All directed edges (adjacency list).
func get_edges() -> Array[BoardEdge]:
	push_error("BoardTopology.get_edges() is abstract — override in subclass")
	return []

## All intersections (branch points). Empty for simple loops.
func get_intersections() -> Array[Intersection]:
	return []

# ─────────────────────────────────────────────────────────────
#  Convenience — derived from get_cells() / get_edges()
# ─────────────────────────────────────────────────────────────

func get_cell_count() -> int:
	return get_cells().size()

## Cell positions in index order, ready for PavementCell placement.
func get_cell_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c in get_cells():
		out.append(c.position)
	return out

## Which logical edge a cell sits on (e.g. &"top").
func get_cell_edge_name(index: int) -> StringName:
	var cells := get_cells()
	if index >= 0 and index < cells.size():
		return cells[index].edge_name
	return &""

# ─────────────────────────────────────────────────────────────
#  Movement — override for non-linear topologies
# ─────────────────────────────────────────────────────────────

## Return the next cell index when moving forward from `from`.
## In a simple loop this is `(from + 1) % cell_count`.
func next_cell(from: int) -> int:
	return (from + 1) % get_cell_count()

## True when stepping from `from` to `to` crosses the lap boundary
## (i.e. the player completes one full traversal).
func is_lap_boundary(from: int, to: int) -> bool:
	push_error("BoardTopology.is_lap_boundary() is abstract — override in subclass")
	return false

## Ordered list of cell indices visited when moving `steps` cells from `from`.
func compute_path(from: int, steps: int) -> Array[int]:
	var path: Array[int] = []
	var pos := from
	for _i in steps:
		pos = next_cell(pos)
		path.append(pos)
	return path

# ─────────────────────────────────────────────────────────────
#  Shop anchoring — override if shops live elsewhere than GameConfig
# ─────────────────────────────────────────────────────────────

## Maps shop_id (StringName) → anchor cell index (int).
func get_shop_cell_indices() -> Dictionary:
	return GameConfig.SHOP_CELL_INDICES

## Lookup: returns the shop_id anchored to `cell_index`, or &"" if none.
func get_shop_at(cell_index: int) -> StringName:
	for sid: StringName in get_shop_cell_indices():
		if get_shop_cell_indices()[sid] == cell_index:
			return sid
	return &""

# ─────────────────────────────────────────────────────────────
#  Geometry — override for board-specific layout
# ─────────────────────────────────────────────────────────────

## The rectangle inside which shop markers are placed (building interior).
## Returns Rect2() if the topology has no such area.
func get_inner_rect() -> Rect2:
	return Rect2()

## Axis-aligned bounding box of all cell positions (with half-cell padding).
## Used by the camera to frame the board.
func get_bounding_rect() -> Rect2:
	var positions := get_cell_positions()
	if positions.is_empty():
		return Rect2()
	var cs := GameConfig.CELL_SIZE
	var min_pos := positions[0]
	var max_pos := positions[0]
	for p in positions:
		min_pos = Vector2(minf(min_pos.x, p.x), minf(min_pos.y, p.y))
		max_pos = Vector2(maxf(max_pos.x, p.x), maxf(max_pos.y, p.y))
	return Rect2(
		min_pos - cs * 0.5,
		max_pos - min_pos + cs
	)
