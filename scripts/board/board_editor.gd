## @tool scene root script for the TileMap-based board editor.
##
## Place tiles on CellsLayer using the board TileSet.  Each tile's
## custom data (cell_type, street_id, shop_id, cross_targets) defines
## the board topology.  Press the "Export Graph" button (or call
## export_graph()) to generate a BoardGraph .tres file.
##
## Scene tree expected:
##   BoardEditor (Node2D)
##     CellsLayer      (TileMapLayer)
##     StreetsLayer     (TileMapLayer)  — visual-only street overlay
##     BuildingsLayer  (TileMapLayer)  — non-traversable building fill
##     ExportButton    (Button)
@tool
class_name BoardEditor
extends Node2D

@export var export_path: String = "res://data/boards/paris_district_v1.tres"

@export_category("Validation")
@export var highlight_errors: bool = true

@onready var cells_layer: TileMapLayer = $CellsLayer
@onready var streets_layer: TileMapLayer = $StreetsLayer
@onready var buildings_layer: TileMapLayer = $BuildingsLayer

var _export_button: Button = null

func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_export_button()
		_ensure_tileset()

func _setup_export_button() -> void:
	_export_button = get_node_or_null("ExportButton") as Button
	if _export_button:
		if not _export_button.pressed.is_connected(_on_export_pressed):
			_export_button.pressed.connect(_on_export_pressed)

func _ensure_tileset() -> void:
	if cells_layer and cells_layer.tile_set == null:
		var path := BoardTilesetBuilder.SAVE_PATH
		if ResourceLoader.exists(path):
			var ts := load(path) as TileSet
			cells_layer.tile_set = ts
			streets_layer.tile_set = ts
			buildings_layer.tile_set = ts
		else:
			push_warning(
				"BoardEditor: TileSet not found at %s — run "
				+ "BoardTilesetBuilder.build_and_save() first" % path
			)

func _on_export_pressed() -> void:
	export_graph()

## Run the exporter and save the BoardGraph .tres.
func export_graph() -> void:
	if cells_layer == null:
		push_error("BoardEditor: CellsLayer node not found")
		return

	var exporter := BoardTilemapExporter.new()
	var graph := exporter.export_from_layer(
		cells_layer, buildings_layer
	)
	if graph == null:
		push_error("BoardEditor: export returned null")
		return

	var dir := export_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := ResourceSaver.save(graph, export_path)
	if err == OK:
		print("BoardEditor: exported BoardGraph → %s (%d nodes)"
			% [export_path, graph.get_node_count()])
	else:
		push_error(
			"BoardEditor: save failed → %s (error %d)"
			% [export_path, err]
		)

## Editor-time validation: prints warnings for tiles missing
## required metadata.
func validate_tiles() -> Array[String]:
	var warnings: Array[String] = []
	if cells_layer == null:
		warnings.append("CellsLayer not found")
		return warnings

	for coord: Vector2i in cells_layer.get_used_cells():
		var data := cells_layer.get_cell_tile_data(coord)
		if data == null:
			continue
		var ct: int = data.get_custom_data("cell_type")
		var sid: String = data.get_custom_data("street_id")
		if ct != BoardTilesetBuilder.CellType.BUILDING and sid == "":
			warnings.append(
				"Tile at %s has no street_id" % str(coord)
			)
		if ct == BoardTilesetBuilder.CellType.SHOP:
			var shop: String = data.get_custom_data("shop_id")
			if shop == "":
				warnings.append(
					"Shop tile at %s has no shop_id" % str(coord)
				)

	if not warnings.is_empty():
		for w in warnings:
			push_warning("BoardEditor: %s" % w)
	else:
		print("BoardEditor: all tiles valid")
	return warnings
