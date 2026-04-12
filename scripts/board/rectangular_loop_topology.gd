## 34-cell rectangular pavement loop around a central building.
## Implements BoardTopology for the current board layout.
##
## TODO: will support Paris-district topology and graph-based routing.
class_name RectangularLoopTopology
extends BoardTopology

var _cells: Array[BoardCell] = []
var _edges: Array[BoardEdge] = []
var _inner_rect: Rect2

func _init() -> void:
	_build_cells()
	_build_edges()
	_inner_rect = _compute_inner_rect()

# ─────────────────────────────────────────────────────────────
#  BoardTopology overrides
# ─────────────────────────────────────────────────────────────

func get_cells() -> Array[BoardCell]:
	return _cells

func get_edges() -> Array[BoardEdge]:
	return _edges

func get_intersections() -> Array[Intersection]:
	return []  # simple loop — no branch points

func is_lap_boundary(from: int, to: int) -> bool:
	return from == GameConfig.LOOP_END_INDEX and to == GameConfig.LOOP_START_INDEX

func get_inner_rect() -> Rect2:
	return _inner_rect

# ─────────────────────────────────────────────────────────────
#  Geometry builder
# ─────────────────────────────────────────────────────────────

func _build_cells() -> void:
	var positions := _build_loop_positions()
	assert(
		positions.size() == GameConfig.LOOP_CELL_COUNT,
		"RectangularLoopTopology: expected %d positions, got %d" % [
			GameConfig.LOOP_CELL_COUNT, positions.size()
		]
	)
	for i in positions.size():
		_cells.append(BoardCell.new(i, positions[i], _edge_for_index(i)))

func _build_edges() -> void:
	for i in _cells.size():
		_edges.append(BoardEdge.new(i, (i + 1) % _cells.size()))

## Returns LOOP_CELL_COUNT world positions walking clockwise from the top-left.
## Coordinate system: top-left cell at (0, 0); x → right, y → down.
func _build_loop_positions() -> Array[Vector2]:
	var pos: Array[Vector2] = []
	var cs := GameConfig.CELL_SIZE

	# Top row: left → right (cells 0 .. LOOP_TOP_COUNT-1)
	for i in GameConfig.LOOP_TOP_COUNT:
		pos.append(Vector2(i * cs.x, 0.0))

	# Right column: top → bottom
	var right_x := (GameConfig.LOOP_TOP_COUNT - 1) * cs.x
	for i in GameConfig.LOOP_RIGHT_COUNT:
		pos.append(Vector2(right_x, (i + 1) * cs.y))

	# Bottom row: right → left
	var bottom_y := GameConfig.LOOP_RIGHT_COUNT * cs.y
	for i in GameConfig.LOOP_BOTTOM_COUNT:
		pos.append(Vector2((GameConfig.LOOP_TOP_COUNT - 2 - i) * cs.x, bottom_y))

	# Left column: bottom → top
	for i in GameConfig.LOOP_LEFT_COUNT:
		pos.append(Vector2(0.0, (GameConfig.LOOP_RIGHT_COUNT - 1 - i) * cs.y))

	# Loop-closure assertion.
	if pos.size() == GameConfig.LOOP_CELL_COUNT:
		var gap := pos[GameConfig.LOOP_END_INDEX].distance_to(pos[GameConfig.LOOP_START_INDEX])
		assert(
			is_equal_approx(gap, cs.x) or is_equal_approx(gap, cs.y),
			"RectangularLoopTopology: loop does not close — gap is %.1fpx" % gap
		)
	return pos

func _edge_for_index(index: int) -> StringName:
	if index < GameConfig.LOOP_TOP_COUNT:
		return &"top"
	elif index < GameConfig.LOOP_TOP_COUNT + GameConfig.LOOP_RIGHT_COUNT:
		return &"right"
	elif index < GameConfig.LOOP_TOP_COUNT + GameConfig.LOOP_RIGHT_COUNT + GameConfig.LOOP_BOTTOM_COUNT:
		return &"bottom"
	else:
		return &"left"

func _compute_inner_rect() -> Rect2:
	var cs  := GameConfig.CELL_SIZE
	var pad := GameConfig.BUILDING_INNER_PADDING

	var inner_left   := cs.x * 0.5
	var inner_top    := cs.y * 0.5
	var inner_right  := (GameConfig.LOOP_TOP_COUNT - 1) * cs.x - cs.x * 0.5
	var inner_bottom := GameConfig.LOOP_RIGHT_COUNT * cs.y - cs.y * 0.5

	return Rect2(
		Vector2(inner_left + pad.x, inner_top + pad.y),
		Vector2(inner_right  - inner_left  - 2.0 * pad.x,
		        inner_bottom - inner_top   - 2.0 * pad.y)
	)
