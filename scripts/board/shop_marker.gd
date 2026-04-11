## Purely presentational shop marker placed INSIDE the building area.
## A Line2D tether connects the shop to its anchor pavement cell on the loop perimeter.
## This node never writes to PlayerData — gameplay authority stays with
## TurnManager + GameConfig.SHOP_CELL_INDICES.
##
## TODO: replace ColorRect fallback with real shop illustrations under
##       assets/boards/shops/ once artwork is available.
## TODO: collision-avoid overlapping labels when two anchor cells are very close
##       (currently prevented by the SHOP_MIN_SEPARATION retry in LoopBoard).
## TODO: allow manual authoring of fixed shop layouts via a Resource preset
##       (for tutorials / scripted levels).
class_name ShopMarker
extends Node2D

var _shop_id: StringName = &""
var _anchor_cell_index: int = -1

# Visual nodes — created in _ready(), configured in setup().
var _tether: Line2D
var _sprite: ColorRect   # TODO: replace with Sprite2D once art is ready
var _label_bg: ColorRect
var _label: Label

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	# Tether first so it renders behind the shop sprite.
	_tether = Line2D.new()
	_tether.width         = 1.5
	_tether.default_color = Color(0.3, 0.3, 0.3, 0.5)
	add_child(_tether)

	# Shop body — ColorRect stands in for a real sprite.
	_sprite = ColorRect.new()
	_sprite.size     = GameConfig.SHOP_VISUAL_SIZE
	_sprite.position = -GameConfig.SHOP_VISUAL_SIZE * 0.5
	add_child(_sprite)

	# Dark backing so the label is readable against the building background.
	var lbl_w := GameConfig.SHOP_VISUAL_SIZE.x + 8.0
	_label_bg          = ColorRect.new()
	_label_bg.color    = Color(0.0, 0.0, 0.0, 0.65)
	_label_bg.size     = Vector2(lbl_w, 20.0)
	_label_bg.position = GameConfig.SHOP_LABEL_OFFSET + Vector2(-lbl_w * 0.5, -10.0)
	add_child(_label_bg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.custom_minimum_size = Vector2(GameConfig.SHOP_VISUAL_SIZE.x, 0.0)
	_label.position = GameConfig.SHOP_LABEL_OFFSET + Vector2(
		-GameConfig.SHOP_VISUAL_SIZE.x * 0.5,
		-10.0
	)
	add_child(_label)

## Configure the marker for a specific shop.
## `target_position` is in LoopBoard local space (same space as ShopsLayer, which sits
## at LoopBoard origin). The tether Line2D runs from this marker's centre (origin) to
## the anchor cell's centre, both expressed in ShopMarker local coordinates.
## Called once by LoopBoard after add_child(); must not be called again mid-game.
func setup(shop: Shop, anchor_cell: PavementCell, target_position: Vector2) -> void:
	_shop_id           = shop.id
	_anchor_cell_index = anchor_cell.index

	# Position in ShopsLayer space (= LoopBoard space, ShopsLayer is at origin).
	position = target_position

	# Tether: from this node's centre (0, 0 local) to the anchor cell centre
	# expressed in this node's local space.
	_tether.points = [Vector2.ZERO, anchor_cell.position - position]

	_sprite.color = shop.color
	_label.text   = shop.display_name

# ---- Public query API ----

func get_anchor_cell_index() -> int:
	return _anchor_cell_index

func get_shop_id() -> StringName:
	return _shop_id
