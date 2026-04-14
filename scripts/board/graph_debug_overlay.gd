## Full debug overlay for the BoardGraph — toggle with F12.
##
## World-space layer:
##   Nodes (blue = even, red = odd, yellow = intersection),
##   edges (coloured per street, arrows for direction),
##   node-ID labels, shop-name labels, start-node ring,
##   pulsing green ring on current player's node,
##   bright choice arrows when an intersection is active.
##
## UI layer (CanvasLayer 20):
##   Scrollable movement log with BBCode colouring.
##   Logs every dice roll, path taken, intersection pause/choice,
##   shop landing, and lap completion.
class_name GraphDebugOverlay
extends Node2D

@export var enabled: bool = false:
	set(v):
		enabled = v
		visible = v
		set_process(v)
		_set_log_visible(v)
		queue_redraw()

var _graph: BoardGraph = null

# ── Street edge colours ──
var _street_colors: Dictionary = {}
var _color_index: int = 0

# ── Intersection pause state (for choice-arrow drawing) ──
var _active_intersection: Intersection = null
var _remaining_at_inter: int = 0

# ── Movement log tracking ──
var _move_start: StringName = &""

# ── Log panel nodes ──
var _log_layer: CanvasLayer = null
var _log_label: RichTextLabel = null

# ═══════════════════════════════════════════════════════════
#  Visual constants
# ═══════════════════════════════════════════════════════════

const _EVEN_COLOR         := Color(0.30, 0.55, 0.90, 0.90)
const _ODD_COLOR          := Color(0.90, 0.30, 0.30, 0.90)
const _INTER_COLOR        := Color(1.0, 0.85, 0.15, 0.95)
const _PLAYER_HL_COLOR    := Color(0.15, 0.90, 0.30, 0.80)
const _SHOP_LABEL_COLOR   := Color(0.95, 0.55, 0.90, 0.95)
const _CHOICE_ARROW_COLOR := Color(1.0, 1.0, 0.3, 0.90)
const _START_RING_COLOR   := Color(0.0, 1.0, 0.5, 0.60)
const _DEFAULT_EDGE_COLOR := Color(0.5, 0.5, 0.5, 0.5)

const _NODE_RADIUS      := 7.0
const _INTER_RADIUS     := 12.0
const _PLAYER_HL_RADIUS := 18.0
const _EDGE_WIDTH       := 2.0
const _INTER_EDGE_WIDTH := 3.5
const _ARROW_HEAD       := 9.0
const _ID_FONT_SIZE     := 8
const _SHOP_FONT_SIZE   := 10
const _CHOICE_FONT_SIZE := 9
const _LOG_FONT_SIZE    := 11

const _PALETTE: Array[Color] = [
	Color(0.90, 0.30, 0.30, 0.75),
	Color(0.30, 0.60, 0.90, 0.75),
	Color(0.30, 0.85, 0.40, 0.75),
	Color(0.90, 0.70, 0.20, 0.75),
	Color(0.75, 0.35, 0.85, 0.75),
	Color(0.20, 0.80, 0.80, 0.75),
	Color(0.85, 0.50, 0.20, 0.75),
	Color(0.60, 0.80, 0.30, 0.75),
]

# ═══════════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════════

func setup(graph: BoardGraph) -> void:
	_graph = graph
	_build_street_colors()
	_build_log_panel()
	_connect_signals()
	visible = enabled
	set_process(enabled)
	queue_redraw()

# ═══════════════════════════════════════════════════════════
#  Input
# ═══════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_F12:
			enabled = not enabled

# ═══════════════════════════════════════════════════════════
#  Process — per-frame redraw for the pulsing player ring
# ═══════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	queue_redraw()

# ═══════════════════════════════════════════════════════════
#  Draw
# ═══════════════════════════════════════════════════════════

func _draw() -> void:
	if _graph == null or not enabled:
		return

	var half := GameConfig.CELL_SIZE * 0.5
	var font := ThemeDB.fallback_font

	_draw_edges(half)
	_draw_nodes(half)
	_draw_node_ids(half, font)
	_draw_shop_labels(half, font)
	_draw_start_marker(half)
	_draw_player_highlight(half)
	_draw_choice_arrows(half, font)

# ── Edges ──

func _draw_edges(half: Vector2) -> void:
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var from := node.position + half
		var col := _color_for_street(node.street_id)
		var w := _INTER_EDGE_WIDTH if node is Intersection else _EDGE_WIDTH
		for next_id: StringName in node.next_nodes:
			var nxt := _graph.get_node_by_id(next_id)
			if nxt == null:
				continue
			var to := nxt.position + half
			draw_line(from, to, col, w)
			_draw_arrowhead(from, to, col)

# ── Nodes ──

func _draw_nodes(half: Vector2) -> void:
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var c := node.position + half
		if node is Intersection:
			draw_circle(c, _INTER_RADIUS, _INTER_COLOR)
			draw_arc(c, _INTER_RADIUS, 0.0, TAU, 24, Color.WHITE, 1.5)
		elif node.side == 1:
			draw_circle(c, _NODE_RADIUS, _ODD_COLOR)
		else:
			draw_circle(c, _NODE_RADIUS, _EVEN_COLOR)

# ── Node ID labels ──

func _draw_node_ids(half: Vector2, font: Font) -> void:
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var c := node.position + half
		var label := String(nid)
		var sz := font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, _ID_FONT_SIZE
		)
		var pos := c + Vector2(
			-sz.x * 0.5, _NODE_RADIUS + _ID_FONT_SIZE + 2
		)
		draw_rect(
			Rect2(pos - Vector2(2, _ID_FONT_SIZE), sz + Vector2(4, 4)),
			Color(0, 0, 0, 0.55)
		)
		draw_string(
			font, pos, label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _ID_FONT_SIZE,
			Color(1, 1, 1, 0.85)
		)

# ── Shop name labels (above node) ──

func _draw_shop_labels(half: Vector2, font: Font) -> void:
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		if node.shop_id == &"":
			continue
		var c := node.position + half
		var label := String(node.shop_id)
		var sz := font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, _SHOP_FONT_SIZE
		)
		var pos := c + Vector2(-sz.x * 0.5, -_NODE_RADIUS - 4)
		draw_rect(
			Rect2(
				pos - Vector2(3, _SHOP_FONT_SIZE),
				sz + Vector2(6, 4)
			),
			Color(0.12, 0.04, 0.10, 0.75)
		)
		draw_string(
			font, pos, label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _SHOP_FONT_SIZE,
			_SHOP_LABEL_COLOR
		)

# ── Start-node ring ──

func _draw_start_marker(half: Vector2) -> void:
	if _graph.start_node_id == &"":
		return
	var sn := _graph.get_node_by_id(_graph.start_node_id)
	if sn == null:
		return
	draw_arc(
		sn.position + half, _PLAYER_HL_RADIUS + 5,
		0.0, TAU, 32, _START_RING_COLOR, 2.0
	)

# ── Pulsing green ring on the current player's node ──

func _draw_player_highlight(half: Vector2) -> void:
	var player := TurnManager.get_current_player()
	if player == null or player.board_node_id == &"":
		return
	var pn := _graph.get_node_by_id(player.board_node_id)
	if pn == null:
		return
	var c := pn.position + half
	var t := fmod(Time.get_ticks_msec() / 600.0, TAU)
	var pulse := 1.0 + 0.12 * sin(t)
	var r := _PLAYER_HL_RADIUS * pulse
	draw_arc(c, r, 0.0, TAU, 32, _PLAYER_HL_COLOR, 3.0)
	draw_arc(
		c, r + 3.0, 0.0, TAU, 32,
		_PLAYER_HL_COLOR * 0.4, 1.5
	)

# ── Choice arrows when waiting at an intersection ──

func _draw_choice_arrows(half: Vector2, font: Font) -> void:
	if _active_intersection == null:
		return
	var inter := _active_intersection
	var ic := inter.position + half
	for i in inter.choice_count:
		if i >= inter.choice_destinations.size():
			break
		var dest_id: StringName = inter.choice_destinations[i]
		var dest := _graph.get_node_by_id(dest_id)
		if dest == null:
			continue
		var dc := dest.position + half
		draw_line(ic, dc, _CHOICE_ARROW_COLOR, _INTER_EDGE_WIDTH)
		_draw_arrowhead(ic, dc, _CHOICE_ARROW_COLOR)
		var mid := ic.lerp(dc, 0.45)
		var label := "[%d]" % i
		if i < inter.choice_labels.size():
			label += " %s" % String(inter.choice_labels[i])
		var sz := font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, _CHOICE_FONT_SIZE
		)
		var lpos := mid + Vector2(-sz.x * 0.5, -10)
		draw_rect(
			Rect2(
				lpos - Vector2(2, _CHOICE_FONT_SIZE),
				sz + Vector2(4, 4)
			),
			Color(0, 0, 0, 0.75)
		)
		draw_string(
			font, lpos, label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _CHOICE_FONT_SIZE,
			_CHOICE_ARROW_COLOR
		)

# ═══════════════════════════════════════════════════════════
#  Arrowhead helper
# ═══════════════════════════════════════════════════════════

func _draw_arrowhead(
	from: Vector2, to: Vector2, color: Color
) -> void:
	var dir := (to - from).normalized()
	if dir.is_zero_approx():
		return
	var mid := from.lerp(to, 0.65)
	var perp := Vector2(-dir.y, dir.x)
	var p1 := mid - dir * _ARROW_HEAD + perp * _ARROW_HEAD * 0.5
	var p2 := mid - dir * _ARROW_HEAD - perp * _ARROW_HEAD * 0.5
	draw_polygon(
		PackedVector2Array([mid, p1, p2]),
		PackedColorArray([color, color, color])
	)

# ═══════════════════════════════════════════════════════════
#  Signal connections
# ═══════════════════════════════════════════════════════════

func _connect_signals() -> void:
	TurnManager.step_action_started.connect(_on_dbg_step)
	TurnManager.dice_rolled.connect(_on_dbg_dice)
	TurnManager.intersection_reached.connect(_on_dbg_inter)
	TurnManager.intersection_resolved.connect(_on_dbg_resolved)
	TurnManager.empty_cell_landed.connect(_on_dbg_empty)
	TurnManager.shop_landed.connect(_on_dbg_shop)
	TurnManager.lap_completed.connect(_on_dbg_lap)
	GameManager.player_data_changed.connect(_on_dbg_pdata)

# ═══════════════════════════════════════════════════════════
#  Event handlers — logging + state tracking
# ═══════════════════════════════════════════════════════════

func _on_dbg_step(pid: int) -> void:
	var player := GameManager.get_player(pid)
	if player == null:
		return
	_move_start = player.board_node_id
	_active_intersection = null
	_add_log(
		"[color=#cccc66]── Step %d: %s ──[/color]"
		% [TurnManager.get_step_action_count() + 1,
		   player.display_name]
	)
	queue_redraw()

func _on_dbg_dice(pid: int, value: int) -> void:
	var player := GameManager.get_player(pid)
	if player == null:
		return
	_move_start = player.board_node_id
	var path := TurnManager.compute_path(_move_start, value)
	var parts: PackedStringArray = PackedStringArray()
	parts.append(String(_move_start))
	for nid: StringName in path:
		parts.append(String(nid))
	_add_log(
		"[color=cyan]Rolled %d: %s (%d steps)[/color]"
		% [value, " \u2192 ".join(parts), value]
	)

func _on_dbg_inter(pid: int, inter: Intersection) -> void:
	_active_intersection = inter
	_remaining_at_inter = TurnManager.get_remaining_steps()
	var choices: PackedStringArray = PackedStringArray()
	for i in inter.choice_count:
		if i < inter.choice_labels.size():
			choices.append(
				"[%d] %s" % [i, String(inter.choice_labels[i])]
			)
	_add_log(
		"[color=yellow]\u26A1 Intersection %s [%d steps left][/color]"
		% [inter.id, _remaining_at_inter]
	)
	_add_log(
		"[color=#999999]  %s[/color]" % "  ".join(choices)
	)
	queue_redraw()

func _on_dbg_resolved(pid: int, chosen: int) -> void:
	if _active_intersection == null:
		return
	var inter := _active_intersection
	var idx := clampi(chosen, 0, inter.choice_count - 1)
	var dest: StringName = inter.choice_destinations[idx]
	var lbl := ""
	if idx < inter.choice_labels.size():
		lbl = String(inter.choice_labels[idx])
	_add_log(
		"[color=white]Chose [%d] %s \u2192 %s[/color]"
		% [idx, lbl, dest]
	)
	var remain := _remaining_at_inter - 1
	if remain > 0:
		var cont := _graph.compute_path(dest, remain)
		if not cont.is_empty():
			var cparts: PackedStringArray = PackedStringArray()
			cparts.append(String(dest))
			for nid: StringName in cont:
				cparts.append(String(nid))
			_add_log(
				"[color=cyan]  \u2192 %s[/color]"
				% " \u2192 ".join(cparts)
			)
	_active_intersection = null
	queue_redraw()

func _on_dbg_empty(_pid: int) -> void:
	var player := TurnManager.get_current_player()
	if player:
		_add_log("Landed: %s (empty)" % player.board_node_id)

func _on_dbg_shop(_pid: int, shop_id: StringName) -> void:
	var player := TurnManager.get_current_player()
	if player:
		_add_log(
			"[color=magenta]Landed: %s (shop: %s)[/color]"
			% [player.board_node_id, shop_id]
		)

func _on_dbg_lap(pid: int, laps: int) -> void:
	var player := GameManager.get_player(pid)
	if player:
		_add_log(
			"[color=green]%s completed lap %d![/color]"
			% [player.display_name, laps]
		)

func _on_dbg_pdata(
	_player: PlayerData, prop: String
) -> void:
	if prop == "board_node_id":
		queue_redraw()

# ═══════════════════════════════════════════════════════════
#  Log panel (CanvasLayer — screen-space, right side)
# ═══════════════════════════════════════════════════════════

func _build_log_panel() -> void:
	_log_layer = CanvasLayer.new()
	_log_layer.layer = 20
	_log_layer.name = "DebugLogLayer"
	add_child(_log_layer)

	var panel := PanelContainer.new()
	panel.name = "LogPanel"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left   = -380
	panel.offset_top    = 8
	panel.offset_right  = -8
	panel.offset_bottom = -64

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.06, 0.88)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", bg)
	_log_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "Debug Log [F12]"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override(
		"font_color", Color(0.7, 0.7, 0.4)
	)
	vbox.add_child(header)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override(
		"normal_font_size", _LOG_FONT_SIZE
	)
	vbox.add_child(_log_label)

	_set_log_visible(enabled)

func _set_log_visible(v: bool) -> void:
	if _log_layer:
		_log_layer.visible = v

func _add_log(line: String) -> void:
	if _log_label:
		_log_label.append_text(line + "\n")

# ═══════════════════════════════════════════════════════════
#  Street colour helpers
# ═══════════════════════════════════════════════════════════

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
		return _DEFAULT_EDGE_COLOR
	if _street_colors.has(street_id):
		return _street_colors[street_id]
	var c := _PALETTE[_color_index % _PALETTE.size()]
	_street_colors[street_id] = c
	_color_index += 1
	return c
