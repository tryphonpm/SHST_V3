## A single traversable cell in the board graph.
## Serialisable as a Resource so the full graph can be saved as a .tres file.
##
## TODO: will support Paris-district topology — nodes may belong to different
##       streets with their own visual themes and gameplay rules.
class_name BoardNode
extends Resource

## Unique identifier for this node (e.g. &"cell_0", &"bakery_junction").
@export var id: StringName = &""

## World position in LoopBoard local space.
@export var position: Vector2 = Vector2.ZERO

## Which street / edge this node belongs to (e.g. &"top", &"rue_de_rivoli").
@export var street_id: StringName = &""

## Side of the street: 0 = even/pair, 1 = odd/impair.
@export var side: int = 0

## If non-empty, this node is a shop anchor. The shop_id matches an entry in
## CatalogManager / data/shops/*.tres.
@export var shop_id: StringName = &""

## Directed adjacency: the node IDs reachable in one step from this node.
## A simple loop has exactly one next node; intersections have two or more.
@export var next_nodes: Array[StringName] = []

## 1-based display number for HUD (matches the board visual labelling).
@export var display_index: int = 0
