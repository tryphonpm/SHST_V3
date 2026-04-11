## Pure traversal tile on the street.
## This node has no knowledge of shops — gameplay anchoring lives in
## GameConfig.SHOP_CELL_INDICES; visual placement lives in ShopMarker.
class_name PavementCell
extends Node2D

## Cell index on the street (0-based).
@export var index: int = 0

var _bg: ColorRect
var _label: Label

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	# TODO: replace placeholder ColorRect with real pavement tile art
	_bg = ColorRect.new()
	_bg.size = GameConfig.CELL_SIZE
	_bg.position = -GameConfig.CELL_SIZE * 0.5
	_bg.color = Color(0.35, 0.35, 0.4, 1.0)
	add_child(_bg)

	_label = Label.new()
	_label.text = str(index)
	_label.position = -GameConfig.CELL_SIZE * 0.5 + Vector2(4, 2)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(_label)

func get_world_anchor() -> Vector2:
	return global_position
