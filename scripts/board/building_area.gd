## Purely decorative node representing the building in the centre of the loop.
## Created programmatically by LoopBoard.build(); never intercepts input.
##
## TODO: replace placeholder ColorRect + hatched style with real art (NinePatchRect
##       or a dedicated texture) under assets/boards/.
class_name BuildingArea
extends Node2D

var _rect: Rect2  # in LoopBoard local coordinates

## Configure and draw the building.
## `rect` must be in LoopBoard local space (same space as cell positions).
func setup(rect: Rect2) -> void:
	_rect = rect
	_build_visuals()

## Returns the building rectangle in LoopBoard local space.
## LoopBoard uses this to compute the valid placement area for shop markers.
func get_inner_rect() -> Rect2:
	return _rect

func _build_visuals() -> void:
	# --- Background ---
	var bg := ColorRect.new()
	bg.position = _rect.position
	bg.size     = _rect.size
	bg.color    = Color(0.88, 0.88, 0.84, 1.0)   # light warm grey — hatched art goes here
	add_child(bg)

	# --- Thin outline ---
	var outline := Line2D.new()
	outline.width         = 2.0
	outline.default_color = Color(0.55, 0.55, 0.5, 1.0)
	outline.joint_mode    = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode   = Line2D.LINE_CAP_ROUND
	# Close the rectangle by repeating the first point.
	var tl := _rect.position
	var br := _rect.end
	outline.points = PackedVector2Array([
		tl,
		Vector2(br.x, tl.y),
		br,
		Vector2(tl.x, br.y),
		tl,
	])
	add_child(outline)

	# --- BUILDING label ---
	var label := Label.new()
	label.text                    = "BUILDING"
	label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))
	label.position = _rect.position
	label.size     = _rect.size
	add_child(label)
