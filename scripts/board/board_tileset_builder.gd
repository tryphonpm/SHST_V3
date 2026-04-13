## Programmatic builder for the board editor TileSet.
##
## Creates a TileSet with custom data layers for board metadata and
## placeholder tile sources.  Run build_and_save() from an @tool
## script or the editor to regenerate the .tres file.
##
## Custom data layers on every tile:
##   cell_type    (int)    0=pavement_even 1=pavement_odd
##                         2=intersection 3=shop 4=building
##   street_id    (String) which street this cell belongs to
##   shop_id      (String) shop id if cell_type==3, empty otherwise
##   cross_targets(String) comma-separated "x,y" grid coords for
##                         manual cross-street edges
##
## TileMap is the visual authoring layer; BoardGraph is the gameplay
## logic layer.  The TileMap is NEVER read at runtime.
class_name BoardTilesetBuilder
extends RefCounted

enum CellType {
	PAVEMENT_EVEN  = 0,
	PAVEMENT_ODD   = 1,
	INTERSECTION   = 2,
	SHOP           = 3,
	BUILDING       = 4,
}

const TILE_SIZE := Vector2i(96, 96)

const SAVE_PATH := "res://resources/board_tileset.tres"

static var _tile_colors: Dictionary = {
	CellType.PAVEMENT_EVEN: Color(0.72, 0.72, 0.76),
	CellType.PAVEMENT_ODD:  Color(0.55, 0.55, 0.60),
	CellType.INTERSECTION:  Color(0.85, 0.75, 0.30),
	CellType.SHOP:          Color(0.40, 0.70, 0.45),
	CellType.BUILDING:      Color(0.25, 0.22, 0.28),
}

## Build the TileSet in memory and return it.
static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE

	_add_custom_data_layers(ts)

	for cell_type: int in _tile_colors:
		_add_tile_source(ts, cell_type)

	return ts

## Build and save to disk. Returns OK on success.
static func build_and_save() -> Error:
	var ts := build()
	var dir := SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return ResourceSaver.save(ts, SAVE_PATH)

# ─────────────────────────────────────────────────────────────

static func _add_custom_data_layers(ts: TileSet) -> void:
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "cell_type")
	ts.set_custom_data_layer_type(0, TYPE_INT)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "street_id")
	ts.set_custom_data_layer_type(1, TYPE_STRING)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(2, "shop_id")
	ts.set_custom_data_layer_type(2, TYPE_STRING)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(3, "cross_targets")
	ts.set_custom_data_layer_type(3, TYPE_STRING)

static func _add_tile_source(
	ts: TileSet, cell_type: int
) -> void:
	var img := Image.create(
		TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8
	)
	var color: Color = _tile_colors[cell_type]
	img.fill(color)

	if cell_type == CellType.INTERSECTION:
		_draw_cross_marker(img, Color.WHITE)
	elif cell_type == CellType.SHOP:
		_draw_shop_marker(img, Color.WHITE)

	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = TILE_SIZE

	var _source_id := ts.add_source(src)
	src.create_tile(Vector2i.ZERO)
	var data := src.get_tile_data(Vector2i.ZERO, 0)
	data.set_custom_data("cell_type", cell_type)
	data.set_custom_data("street_id", "")
	data.set_custom_data("shop_id", "")
	data.set_custom_data("cross_targets", "")

static func _draw_cross_marker(
	img: Image, color: Color
) -> void:
	@warning_ignore("INTEGER_DIVISION")
	var cx := TILE_SIZE.x / 2
	@warning_ignore("INTEGER_DIVISION")
	var cy := TILE_SIZE.y / 2
	var arm := 16
	for i in range(-arm, arm + 1):
		for w in range(-2, 3):
			var px := clampi(cx + i, 0, TILE_SIZE.x - 1)
			var py := clampi(cy + w, 0, TILE_SIZE.y - 1)
			img.set_pixel(px, py, color)
			px = clampi(cx + w, 0, TILE_SIZE.x - 1)
			py = clampi(cy + i, 0, TILE_SIZE.y - 1)
			img.set_pixel(px, py, color)

static func _draw_shop_marker(
	img: Image, color: Color
) -> void:
	@warning_ignore("INTEGER_DIVISION")
	var cx := TILE_SIZE.x / 2
	@warning_ignore("INTEGER_DIVISION")
	var cy := TILE_SIZE.y / 2
	var r := 14
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				var px := clampi(x, 0, TILE_SIZE.x - 1)
				var py := clampi(y, 0, TILE_SIZE.y - 1)
				img.set_pixel(px, py, color)
