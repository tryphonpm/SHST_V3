## A board node where multiple paths branch — the player must choose a
## direction before movement continues.
##
## Inherits all of BoardNode (id, position, street_id, side, shop_id,
## next_nodes, display_index) and adds labelled choices that map 1-to-1
## onto next_nodes.
##
## TODO: will support Paris-district topology — intersections may have
##       per-choice probabilities for AI players.
class_name Intersection
extends BoardNode

## How many paths branch from this node (2-4). Must equal
## choice_labels.size(), choice_destinations.size(), and next_nodes.size().
@export var choice_count: int = 2

## Short UI labels shown on each button (e.g. &"left", &"straight").
@export var choice_labels: Array[StringName] = []

## Node IDs reachable via each choice — same order as choice_labels.
## Kept in sync with next_nodes for serialisation clarity; at runtime
## next_nodes is the authoritative adjacency list.
@export var choice_destinations: Array[StringName] = []

## Optional longer text for HUD tooltip / accessibility.
@export var choice_descriptions: Array[String] = []

## Validate that all parallel arrays have consistent sizes.
func validate() -> bool:
	if choice_labels.size() != choice_count:
		push_error(
			"Intersection '%s': choice_labels size %d != choice_count %d"
			% [id, choice_labels.size(), choice_count]
		)
		return false
	if choice_destinations.size() != choice_count:
		push_error(
			"Intersection '%s': choice_destinations size %d != choice_count %d"
			% [id, choice_destinations.size(), choice_count]
		)
		return false
	if next_nodes.size() != choice_count:
		push_error(
			"Intersection '%s': next_nodes size %d != choice_count %d"
			% [id, next_nodes.size(), choice_count]
		)
		return false
	return true
