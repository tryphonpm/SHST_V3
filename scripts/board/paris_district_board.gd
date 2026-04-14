## @tool scene root for the Paris district TileMap-based board.
##
## Builds the graph from ParisDistrictTopology and populates 4 TileMapLayer
## children with correctly placed tiles matching the hardcoded node positions.
##
## Layer structure (bottom → top):
##   BuildingsLayer  — interior building fill (dark tiles)
##   CellsLayer      — traversable nodes: pavement_even, pavement_odd,
##                     intersection (1 tile per BoardNode, 48 total)
##   StreetsLayer     — visual street color overlay (tinted per street)
##   ShopsLayer      — shop anchor markers overlaid on shop cells
##   DebugOverlay    — node IDs, graph edges, hover tooltip (Node2D)
##
## Toggle debug overlay with the `show_debug` export or F4 at runtime.
## Run the verification pass from the inspector (`run_verify` checkbox)
## or call verify() from code.
@tool
class_name ParisDistrictBoard
extends Node2D

const CS := 96.0
const HALF := CS * 0.5

@export var show_debug: bool = false:
	set(v):
		show_debug = v
		_update_debug_visibility()

@export_category("Export")
@export var save_graph_tres: bool = false:
	set(v):
		if v and _ready_done:
			_save_graph()
		save_graph_tres = false

@export var run_round_trip: bool = false:
	set(v):
		if v and _ready_done and _graph:
			var issues := BoardGraph.verify_round_trip(_graph)
			if issues.is_empty():
				print("Round-trip: ALL OK")
		run_round_trip = false

@export_category("Verification")
@export var run_verify: bool = false:
	set(v):
		if v and _ready_done:
			verify()
		run_verify = false

var _graph: BoardGraph = null
var _tileset: TileSet = null
var _ready_done := false

@onready var _buildings_layer: TileMapLayer = $BuildingsLayer
@onready var _cells_layer: TileMapLayer = $CellsLayer
@onready var _streets_layer: TileMapLayer = $StreetsLayer
@onready var _shops_layer: TileMapLayer = $ShopsLayer
@onready var _debug_overlay: Node2D = $DebugOverlay

const _STREET_COLORS: Dictionary = {
	&"rue_de_rivoli":    Color(0.55, 0.70, 0.90, 0.25),
	&"rue_saint_honore": Color(0.55, 0.85, 0.60, 0.25),
	&"rue_castiglione":  Color(0.85, 0.65, 0.55, 0.25),
	&"rue_marche":       Color(0.75, 0.55, 0.85, 0.25),
}

# ─────────────────────────────────────────────────────────────
#  Lifecycle
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_and_populate()
	_ready_done = true

func _build_and_populate() -> void:
	var topo := ParisDistrictTopology.new()
	_graph = topo.build_graph()
	_tileset = BoardTilesetBuilder.build()

	_assign_tilesets()
	_populate_buildings()
	_populate_cells()
	_populate_streets_overlay()
	_populate_shops()
	_update_debug_visibility()

	if _debug_overlay and _debug_overlay.has_method("setup"):
		_debug_overlay.setup(_graph)
	queue_redraw()

func get_graph() -> BoardGraph:
	return _graph

# ─────────────────────────────────────────────────────────────
#  TileSet assignment
# ─────────────────────────────────────────────────────────────

func _assign_tilesets() -> void:
	for layer: TileMapLayer in [
		_buildings_layer, _cells_layer, _streets_layer, _shops_layer,
	]:
		if layer:
			layer.tile_set = _tileset

# ─────────────────────────────────────────────────────────────
#  Layer population
# ─────────────────────────────────────────────────────────────

func _populate_cells() -> void:
	if not _cells_layer:
		return
	_cells_layer.clear()
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var grid := _to_grid(node.position)
		var src_id: int
		if node is Intersection:
			src_id = BoardTilesetBuilder.CellType.INTERSECTION
		elif node.side == 0:
			src_id = BoardTilesetBuilder.CellType.PAVEMENT_EVEN
		else:
			src_id = BoardTilesetBuilder.CellType.PAVEMENT_ODD
		_cells_layer.set_cell(grid, src_id, Vector2i.ZERO)

func _populate_buildings() -> void:
	if not _buildings_layer:
		return
	_buildings_layer.clear()
	for row in range(2, 6):
		for col in range(2, 6):
			_buildings_layer.set_cell(
				Vector2i(col, row),
				BoardTilesetBuilder.CellType.BUILDING,
				Vector2i.ZERO
			)

func _populate_streets_overlay() -> void:
	if not _streets_layer:
		return
	_streets_layer.clear()
	_streets_layer.modulate = Color(1, 1, 1, 0.3)
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var grid := _to_grid(node.position)
		var src_id: int
		if node.side == 0:
			src_id = BoardTilesetBuilder.CellType.PAVEMENT_EVEN
		else:
			src_id = BoardTilesetBuilder.CellType.PAVEMENT_ODD
		_streets_layer.set_cell(grid, src_id, Vector2i.ZERO)

func _populate_shops() -> void:
	if not _shops_layer:
		return
	_shops_layer.clear()
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		if node.shop_id != &"":
			_shops_layer.set_cell(
				_to_grid(node.position),
				BoardTilesetBuilder.CellType.SHOP,
				Vector2i.ZERO
			)

# ─────────────────────────────────────────────────────────────
#  Custom draw — street labels, building rect, shop labels
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if _graph == null:
		return
	_draw_building_rect()
	_draw_street_labels()
	_draw_shop_labels()

func _draw_building_rect() -> void:
	var r := _graph.building_rect
	if r.size.x > 0.0 and r.size.y > 0.0:
		draw_rect(r, Color(0.15, 0.13, 0.18, 0.4))
		draw_rect(r, Color(0.4, 0.35, 0.3, 0.6), false, 2.0)

func _draw_street_labels() -> void:
	var font := ThemeDB.fallback_font
	var fsize := 13
	draw_string(
		font, Vector2(2.5 * CS, -10),
		"Rue de Rivoli", HORIZONTAL_ALIGNMENT_CENTER,
		int(3.0 * CS), fsize, Color(0.55, 0.70, 0.90)
	)
	draw_string(
		font, Vector2(2.5 * CS, 8.0 * CS + fsize + 6),
		"Rue Saint-Honoré", HORIZONTAL_ALIGNMENT_CENTER,
		int(3.0 * CS), fsize, Color(0.55, 0.85, 0.60)
	)
	draw_string(
		font, Vector2(-10, 4.0 * CS),
		"Castiglione", HORIZONTAL_ALIGNMENT_RIGHT,
		120, fsize, Color(0.85, 0.65, 0.55)
	)
	draw_string(
		font, Vector2(8.0 * CS + 10, 4.0 * CS),
		"Marché", HORIZONTAL_ALIGNMENT_LEFT,
		120, fsize, Color(0.75, 0.55, 0.85)
	)

func _draw_shop_labels() -> void:
	var font := ThemeDB.fallback_font
	var fsize := 10
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		if node.shop_id == &"":
			continue
		var pos := node.position + Vector2(HALF - 30, CS + fsize + 4)
		draw_string(
			font, pos,
			String(node.shop_id).capitalize(),
			HORIZONTAL_ALIGNMENT_CENTER, 60, fsize, Color.YELLOW
		)

# ─────────────────────────────────────────────────────────────
#  Debug visibility
# ─────────────────────────────────────────────────────────────

func _update_debug_visibility() -> void:
	if _debug_overlay:
		_debug_overlay.visible = show_debug

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_F4:
			show_debug = not show_debug

# ─────────────────────────────────────────────────────────────
#  Verification
# ─────────────────────────────────────────────────────────────

func verify() -> Array[String]:
	var warnings: Array[String] = []
	if _graph == null:
		warnings.append("No graph built")
		_print_verify(warnings)
		return warnings
	if _cells_layer == null:
		warnings.append("CellsLayer not found")
		_print_verify(warnings)
		return warnings

	var graph_grids: Dictionary = {}
	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var grid := _to_grid(node.position)
		graph_grids[grid] = nid

		var src := _cells_layer.get_cell_source_id(grid)
		if src < 0:
			warnings.append(
				"ORPHAN NODE: '%s' at grid %s has no tile" % [nid, grid]
			)

	for coord: Vector2i in _cells_layer.get_used_cells():
		if not graph_grids.has(coord):
			warnings.append(
				"ORPHAN TILE: tile at grid %s has no graph node" % str(coord)
			)

	for nid: StringName in _graph.nodes:
		var node: BoardNode = _graph.nodes[nid]
		var grid := _to_grid(node.position)
		var src := _cells_layer.get_cell_source_id(grid)
		if src < 0:
			continue
		var expected: int
		if node is Intersection:
			expected = BoardTilesetBuilder.CellType.INTERSECTION
		elif node.side == 0:
			expected = BoardTilesetBuilder.CellType.PAVEMENT_EVEN
		else:
			expected = BoardTilesetBuilder.CellType.PAVEMENT_ODD
		if src != expected:
			warnings.append(
				"TYPE MISMATCH: '%s' expected source %d got %d"
				% [nid, expected, src]
			)

	if _shops_layer:
		for nid: StringName in _graph.nodes:
			var node: BoardNode = _graph.nodes[nid]
			if node.shop_id == &"":
				continue
			var grid := _to_grid(node.position)
			var src := _shops_layer.get_cell_source_id(grid)
			if src < 0:
				warnings.append(
					"MISSING SHOP TILE: '%s' (shop '%s') at %s"
					% [nid, node.shop_id, grid]
				)

	_print_verify(warnings)
	return warnings

func _print_verify(warnings: Array[String]) -> void:
	var total_nodes := _graph.nodes.size() if _graph else 0
	var total_cells := _cells_layer.get_used_cells().size() if _cells_layer else 0
	var total_bldg := _buildings_layer.get_used_cells().size() if _buildings_layer else 0
	var total_shops := _shops_layer.get_used_cells().size() if _shops_layer else 0
	var inter_count := 0
	var shop_count := 0
	if _graph:
		for nid: StringName in _graph.nodes:
			var node: BoardNode = _graph.nodes[nid]
			if node is Intersection:
				inter_count += 1
			if node.shop_id != &"":
				shop_count += 1

	print("=== ParisDistrictBoard Verify ===")
	print("  Graph nodes: %d (intersections: %d, shops: %d)"
		% [total_nodes, inter_count, shop_count])
	print("  CellsLayer tiles:     %d" % total_cells)
	print("  BuildingsLayer tiles: %d" % total_bldg)
	print("  ShopsLayer tiles:     %d" % total_shops)
	if warnings.is_empty():
		print("  ALL OK — no orphans, no misalignment")
	else:
		for w in warnings:
			push_warning("  %s" % w)
	print("=================================")

# ─────────────────────────────────────────────────────────────
#  Graph export
# ─────────────────────────────────────────────────────────────

func _save_graph() -> void:
	if _graph == null:
		push_error("ParisDistrictBoard: no graph to save")
		return
	var path := ParisDistrictTopology.SAVE_PATH
	var err := _graph.save_to_file(path)
	if err == OK:
		print("ParisDistrictBoard: saved graph to %s" % path)
	else:
		push_error("ParisDistrictBoard: save failed (error %d)" % err)

# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────

func _to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pos.x / CS),
		int(pos.y / CS)
	)
