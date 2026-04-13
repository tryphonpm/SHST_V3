## Debug overlay that draws BoardGraph edges and nodes on top of the
## board.  Color-coded by street, with arrows for directed edges and
## larger circles for Intersection nodes.
##
## Toggle at runtime with F3 or set `enabled` from the inspector.
class_name GraphDebugOverlay
extends Node2D

@export var enabled: bool = false:
	set(v):
		enabled = v
		visible = v
		queue_redraw()

var _graph: BoardGraph = null

var _street_colors: Dictionary = {}
var _color_index: int = 0

const _PALETTE: Array[Color] = [
	Color(0.90, 0.30, 0.30, 0.85),
	Color(0.30, 0.60, 0.90, 0.85),
	Color(0.30, 0.85, 0.40, 0.85),
	Color(0.90, 0.70, 0.20, 0.85),
	Color(0.75, 0.35, 0.85, 0.85),
	Color(0.20, 0.80, 0.80, 0.85),
	Color(0.85, 0.50, 0.20, 0.85),
	Color(0.60, 0.80, 0.30, 0.85),
]

const _DEFAULT_COLOR := Color(0.6, 0.6, 0.6, 0.7)
const _INTERSECTION_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const _NODE_RADIUS := 6.0
const _INTERSECTION_RADIUS := 10.0
const _EDGE_WIDTH := 2.0
const _ARROW_SIZE := 8.0

func setup(graph: BoardGraph) -> void:
	_graph = graph
	_build_street_colors()
	visible = enabled
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_F3:
			enabled = not enabled

func _draw() -> void:
	if _graph == null or not enabled:
		return

	var half_cell := GameConfig.CELL_SIZE * 0.5

	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var from := node.position + half_cell

		var edge_color := _color_for_street(node.street_id)

		for next_id: StringName in node.next_nodes:
			var next_node := _graph.get_node_by_id(next_id)
			if next_node == null:
				continue
			var to := next_node.position + half_cell
			draw_line(from, to, edge_color, _EDGE_WIDTH)
			_draw_arrow(from, to, edge_color)

	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var center := node.position + half_cell

		if node is Intersection:
			draw_circle(
				center, _INTERSECTION_RADIUS, _INTERSECTION_COLOR
			)
			draw_arc(
				center, _INTERSECTION_RADIUS, 0.0, TAU, 24,
				Color.WHITE, 1.5
			)
		else:
			var fill := _color_for_street(node.street_id)
			draw_circle(center, _NODE_RADIUS, fill)

		if node.display_index > 0:
			var font := ThemeDB.fallback_font
			var fsize := 10
			var label := str(node.display_index)
			var text_size := font.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize
			)
			draw_string(
				font, center - text_size * 0.5 + Vector2(0, fsize * 0.35),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE
			)

func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := (to - from).normalized()
	if dir.is_zero_approx():
		return
	var mid := from.lerp(to, 0.65)
	var perp := Vector2(-dir.y, dir.x)
	var p1 := mid - dir * _ARROW_SIZE + perp * _ARROW_SIZE * 0.5
	var p2 := mid - dir * _ARROW_SIZE - perp * _ARROW_SIZE * 0.5
	draw_polygon(
		PackedVector2Array([mid, p1, p2]),
		PackedColorArray([color, color, color])
	)

func _build_street_colors() -> void:
	_street_colors.clear()
	_color_index = 0
	if _graph == null:
		return
	for sid: StringName in _graph.streets:
		_street_colors[sid] = _PALETTE[
			_color_index % _PALETTE.size()
		]
		_color_index += 1

func _color_for_street(street_id: StringName) -> Color:
	if street_id == &"":
		return _DEFAULT_COLOR
	if _street_colors.has(street_id):
		return _street_colors[street_id]
	var c := _PALETTE[_color_index % _PALETTE.size()]
	_street_colors[street_id] = c
	_color_index += 1
	return c
