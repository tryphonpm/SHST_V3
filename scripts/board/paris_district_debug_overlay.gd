## Debug overlay for ParisDistrictBoard.
##
## Draws graph edges with directional arrows, node IDs on every cell,
## and a hover tooltip showing full node metadata when the mouse is
## over a tile.  Toggle with F4 or the parent's `show_debug` export.
@tool
class_name ParisDistrictDebugOverlay
extends Node2D

const CS := 96.0
const HALF := CS * 0.5

const _EDGE_COLOR := Color(1, 1, 1, 0.35)
const _ARROW_COLOR := Color(1, 0.9, 0.3, 0.7)
const _ID_COLOR := Color(1, 1, 1, 0.85)
const _HIGHLIGHT_COLOR := Color(1, 1, 1, 0.35)
const _ARROW_SIZE := 6.0

var _graph: BoardGraph = null
var _hovered_id: StringName = &""
var _hover_label: Label = null

func setup(graph: BoardGraph) -> void:
	_graph = graph
	_ensure_hover_label()
	queue_redraw()

func _ready() -> void:
	_ensure_hover_label()

func _ensure_hover_label() -> void:
	if _hover_label != null:
		return
	_hover_label = Label.new()
	_hover_label.name = &"_HoverInfo"
	_hover_label.add_theme_font_size_override("font_size", 11)
	_hover_label.add_theme_color_override("font_color", Color.WHITE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	_hover_label.add_theme_stylebox_override("normal", sb)
	_hover_label.visible = false
	_hover_label.z_index = 100
	add_child(_hover_label, false, Node.INTERNAL_MODE_FRONT)

func _process(_delta: float) -> void:
	if _graph == null or not visible:
		if _hover_label:
			_hover_label.visible = false
		return

	var mouse := get_local_mouse_position()
	if mouse.x < 0.0 or mouse.y < 0.0:
		_set_hovered(&"")
		return

	var grid := Vector2i(int(mouse.x / CS), int(mouse.y / CS))
	var found: StringName = &""
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var ng := Vector2i(
			int(node.position.x / CS),
			int(node.position.y / CS)
		)
		if ng == grid:
			found = nid
			break

	_set_hovered(found)
	if _hover_label and _hover_label.visible:
		_hover_label.position = mouse + Vector2(16, -20)

func _set_hovered(nid: StringName) -> void:
	if nid == _hovered_id:
		return
	_hovered_id = nid
	queue_redraw()
	if _hover_label == null:
		return
	if nid == &"":
		_hover_label.visible = false
		return

	var node: BoardNode = _graph.nodes[nid]
	var text := "ID: %s" % nid
	text += "\nStreet: %s" % node.street_id
	text += "\nSide: %s" % ("even (forward)" if node.side == 0 else "odd (reverse)")
	text += "\nDisplay: #%d" % node.display_index
	text += "\nPos: %s  Grid: (%d,%d)" % [
		str(node.position),
		int(node.position.x / CS),
		int(node.position.y / CS),
	]
	if node is Intersection:
		var inter := node as Intersection
		text += "\nType: INTERSECTION (%d choices)" % inter.choice_count
		for i in inter.choice_labels.size():
			text += "\n  %s -> %s" % [
				inter.choice_labels[i],
				inter.choice_destinations[i],
			]
	if node.shop_id != &"":
		text += "\nShop: %s" % node.shop_id
	text += "\nNext: %s" % str(node.next_nodes)
	_hover_label.text = text
	_hover_label.visible = true

# ─────────────────────────────────────────────────────────────
#  Drawing
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if _graph == null:
		return
	_draw_edges()
	_draw_node_ids()
	if _hovered_id != &"":
		_draw_highlight()

func _draw_edges() -> void:
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var from := node.position + Vector2(HALF, HALF)
		for next_id: StringName in node.next_nodes:
			var next_node := _graph.get_node_by_id(next_id)
			if next_node == null:
				continue
			var to := next_node.position + Vector2(HALF, HALF)
			draw_line(from, to, _EDGE_COLOR, 1.5)
			_draw_arrow(from, to)

func _draw_arrow(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	if dir.is_zero_approx():
		return
	var mid := from.lerp(to, 0.6)
	var perp := Vector2(-dir.y, dir.x)
	var p1 := mid - dir * _ARROW_SIZE + perp * _ARROW_SIZE * 0.5
	var p2 := mid - dir * _ARROW_SIZE - perp * _ARROW_SIZE * 0.5
	draw_polygon(
		PackedVector2Array([mid, p1, p2]),
		PackedColorArray([_ARROW_COLOR, _ARROW_COLOR, _ARROW_COLOR])
	)

func _draw_node_ids() -> void:
	var font := ThemeDB.fallback_font
	var fsize := 8
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		draw_string(
			font,
			node.position + Vector2(2, CS - 4),
			String(nid),
			HORIZONTAL_ALIGNMENT_LEFT, int(CS - 4), fsize,
			_ID_COLOR
		)

func _draw_highlight() -> void:
	var node: BoardNode = _graph.nodes.get(_hovered_id)
	if node == null:
		return
	draw_rect(
		Rect2(node.position, Vector2(CS, CS)),
		_HIGHLIGHT_COLOR, false, 3.0
	)
	for next_id: StringName in node.next_nodes:
		var next_node := _graph.get_node_by_id(next_id)
		if next_node == null:
			continue
		draw_rect(
			Rect2(next_node.position, Vector2(CS, CS)),
			Color(0.3, 1.0, 0.3, 0.3), false, 2.0
		)
