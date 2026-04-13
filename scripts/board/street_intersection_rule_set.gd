## Editable rule set defining which transition types are available at
## street-end Intersection nodes.
##
## Parisian district intersection rules — at the end of a sidewalk the
## player encounters a choice node with up to 4 movement options:
##
##   left_turn       → parallel street to the left, same side parity
##   straight_cross  → next block of the same street, same side
##   opposite_side   → same street, opposite parity (reverse direction)
##   right_turn      → perpendicular street entry (turn right)
##
## Each rule can be globally enabled/disabled.  The builder only offers
## a choice when the target street actually exists in the graph.
##
## Save as a .tres to customise per district without code changes.
class_name StreetIntersectionRuleSet
extends Resource

## Canonical choice keys, used as Intersection.choice_labels.
const KEY_LEFT_TURN      := &"left_turn"
const KEY_STRAIGHT_CROSS := &"straight_cross"
const KEY_OPPOSITE_SIDE  := &"opposite_side"
const KEY_RIGHT_TURN     := &"right_turn"

## Human-readable labels for UI buttons.
const DISPLAY_LABELS: Dictionary = {
	KEY_LEFT_TURN:      "Turn Left",
	KEY_STRAIGHT_CROSS: "Cross Straight",
	KEY_OPPOSITE_SIDE:  "Opposite Side",
	KEY_RIGHT_TURN:     "Turn Right",
}

## Arrow/icon hint per choice key.  Values are Unicode arrows that the
## IntersectionPanel and HUD can display directly.
const DIRECTION_ARROWS: Dictionary = {
	KEY_LEFT_TURN:      "\u2B9C",   # ⮜  leftwards arrow
	KEY_STRAIGHT_CROSS: "\u2B9D",   # ⮝  upwards arrow (forward)
	KEY_OPPOSITE_SIDE:  "\u21C5",   # ⇅  up-down arrows
	KEY_RIGHT_TURN:     "\u2B9E",   # ⮞  rightwards arrow
}

## Human-readable descriptions for tooltip / accessibility.
const CHOICE_DESCRIPTIONS: Dictionary = {
	KEY_LEFT_TURN:
		"Turn left without crossing — continue on the parallel street "
		+ "in the same walking direction.",
	KEY_STRAIGHT_CROSS:
		"Cross straight ahead to the next block of this street.",
	KEY_OPPOSITE_SIDE:
		"Cross to the opposite sidewalk — reverse your walking "
		+ "direction on this street.",
	KEY_RIGHT_TURN:
		"Turn right onto the perpendicular street.",
}

@export var allow_left_turn: bool = true
@export var allow_straight_cross: bool = true
@export var allow_opposite_side: bool = true
@export var allow_right_turn: bool = true

## Maximum grid distance (in cells) to consider a street "parallel" or
## "perpendicular" for left/right turn detection.
@export var neighbor_block_distance: float = 2.0

func is_rule_enabled(key: StringName) -> bool:
	match key:
		KEY_LEFT_TURN:
			return allow_left_turn
		KEY_STRAIGHT_CROSS:
			return allow_straight_cross
		KEY_OPPOSITE_SIDE:
			return allow_opposite_side
		KEY_RIGHT_TURN:
			return allow_right_turn
	return false

## Returns the ordered list of enabled rule keys.
func get_enabled_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	if allow_left_turn:
		keys.append(KEY_LEFT_TURN)
	if allow_straight_cross:
		keys.append(KEY_STRAIGHT_CROSS)
	if allow_opposite_side:
		keys.append(KEY_OPPOSITE_SIDE)
	if allow_right_turn:
		keys.append(KEY_RIGHT_TURN)
	return keys

static func get_display_label(key: StringName) -> String:
	return DISPLAY_LABELS.get(key, String(key))

static func get_arrow(key: StringName) -> String:
	return DIRECTION_ARROWS.get(key, "?")

static func get_description(key: StringName) -> String:
	return CHOICE_DESCRIPTIONS.get(key, "")
