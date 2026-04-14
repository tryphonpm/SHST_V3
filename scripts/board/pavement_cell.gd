## Pure traversal tile on the street.
## This node has no knowledge of shops — gameplay anchoring lives in
## the BoardGraph (BoardNode.shop_id); visual placement lives in ShopMarker.
class_name PavementCell
extends Node2D

## Legacy integer index (kept for label display).
@export var index: int = 0

## Graph node ID this cell represents.
@export var node_id: StringName = &""

## 0 = even (forward), 1 = odd (reverse). Used for colour-coding.
@export var side: int = 0

## True for Intersection nodes — rendered with a distinct colour.
@export var is_intersection: bool = false

const _COLOR_EVEN        := Color(0.32, 0.38, 0.45, 1.0)
const _COLOR_ODD         := Color(0.42, 0.32, 0.38, 1.0)
const _COLOR_INTERSECTION := Color(0.80, 0.65, 0.15, 1.0)

var _bg: ColorRect
var _label: Label

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	_bg = ColorRect.new()
	_bg.size = GameConfig.CELL_SIZE
	_bg.position = -GameConfig.CELL_SIZE * 0.5
	if is_intersection:
		_bg.color = _COLOR_INTERSECTION
	elif side == 1:
		_bg.color = _COLOR_ODD
	else:
		_bg.color = _COLOR_EVEN
	add_child(_bg)

	_label = Label.new()
	_label.text = String(node_id) if node_id != &"" else str(index)
	_label.position = -GameConfig.CELL_SIZE * 0.5 + Vector2(4, 2)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	add_child(_label)

func get_world_anchor() -> Vector2:
	return global_position
