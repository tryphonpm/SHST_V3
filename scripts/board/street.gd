## A named street with two directional sidewalks (even and odd sides).
##
## Parisian street-side rule:
##   • Even side (side == 0): nodes traversed in FORWARD order
##     (even_side_nodes[0] → [1] → … → [N-1]).
##   • Odd side  (side == 1): nodes traversed in REVERSE order
##     (odd_side_nodes[last] → … → [1] → [0]).
##     Players walking the odd side physically move in the OPPOSITE
##     direction compared to even-side walkers on the same street.
##
## Same side parity = same physical walking direction.
## Opposite parity  = reverse physical walking direction.
##
## Street-end transitions (encoded as Intersection nodes by the topology
## builder; listed here for documentation):
##   1. Turn left (no crossing): → first node of an adjacent parallel
##      street, SAME side parity (preserves walking direction).
##   2. Cross straight: → next block of the same street, same side.
##      TODO: multi-block streets not yet implemented.
##   3. Cross diagonal (opposite side): → last node of the same
##      street's opposite side (enter at that side's exit, walking
##      back the way you came).
##   4. Cross to transverse street: → entry node of a perpendicular
##      street (side chosen by the topology).
##
## TODO: will support Paris-district topology with real streets
##       (rue de Rivoli, boulevard Haussmann, etc.).
class_name Street
extends Resource

## Unique identifier (e.g. &"rue_de_rivoli", &"loop").
@export var id: StringName = &""

## Human-readable name for UI display.
@export var display_name: String = ""

## Node IDs on the even (pair) sidewalk, listed in FORWARD traversal
## order.  A player entering this side starts at index 0 and exits at
## the last index.
@export var even_side_nodes: Array[StringName] = []

## Node IDs on the odd (impair) sidewalk, listed in their FORWARD
## traversal order (which is the physical REVERSE direction compared
## to the even side).  A player entering this side starts at index 0
## and exits at the last index.
@export var odd_side_nodes: Array[StringName] = []

## IDs of other streets that intersect (cross) this one.
## Used by topology builders to generate Intersection nodes at the
## street boundaries.
@export var intersecting_streets: Array[StringName] = []

# ─────────────────────────────────────────────────────────────
#  Queries
# ─────────────────────────────────────────────────────────────

## Entry node of the requested side (first node in traversal order).
func get_entry_node(p_side: int) -> StringName:
	var arr := _side_array(p_side)
	if arr.is_empty():
		return &""
	return arr[0]

## Exit node of the requested side (last node in traversal order).
func get_exit_node(p_side: int) -> StringName:
	var arr := _side_array(p_side)
	if arr.is_empty():
		return &""
	return arr[arr.size() - 1]

## True if `node_id` belongs to either side of this street.
func has_node(node_id: StringName) -> bool:
	return even_side_nodes.has(node_id) \
		or odd_side_nodes.has(node_id)

## Returns 0 (even) or 1 (odd) for a node on this street,
## or -1 if the node doesn't belong to this street.
func get_side_for_node(node_id: StringName) -> int:
	if even_side_nodes.has(node_id):
		return 0
	if odd_side_nodes.has(node_id):
		return 1
	return -1

## Returns the ordered node array for the given side.
func get_side_nodes(p_side: int) -> Array[StringName]:
	return _side_array(p_side)

## Number of nodes on the given side.
func get_side_length(p_side: int) -> int:
	return _side_array(p_side).size()

## Total nodes across both sides.
func get_node_count() -> int:
	return even_side_nodes.size() + odd_side_nodes.size()

func _side_array(p_side: int) -> Array[StringName]:
	if p_side == 1:
		return odd_side_nodes
	return even_side_nodes
