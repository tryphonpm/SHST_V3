class_name PavementCell
extends Node2D

## Cell index on the street (0-based).
@export var index: int = 0
## If set, this cell is a shop. Empty = plain pavement.
@export var shop_id: StringName = &""

var _bg: ColorRect
var _shop_marker: ColorRect
var _label: Label

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	# TODO: replace placeholder ColorRect visuals with real art once assets are available
	_bg = ColorRect.new()
	_bg.size = GameConfig.CELL_SIZE
	_bg.position = -GameConfig.CELL_SIZE * 0.5
	_bg.color = Color(0.35, 0.35, 0.4, 1.0) if shop_id == &"" else Color(0.25, 0.25, 0.3, 1.0)
	add_child(_bg)

	if shop_id != &"":
		_shop_marker = ColorRect.new()
		_shop_marker.size = GameConfig.CELL_SIZE * 0.6
		_shop_marker.position = -GameConfig.CELL_SIZE * 0.3
		var shop := CatalogManager.get_shop(shop_id)
		_shop_marker.color = shop.color if shop else Color.MAGENTA
		add_child(_shop_marker)

	_label = Label.new()
	_label.text = str(index)
	_label.position = -GameConfig.CELL_SIZE * 0.5 + Vector2(4, 2)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(_label)

func is_shop() -> bool:
	return shop_id != &""

func get_world_anchor() -> Vector2:
	return global_position
