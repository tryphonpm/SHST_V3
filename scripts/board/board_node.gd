## A single traversable cell in the board graph.
## Serialisable as a Resource so the full graph can be saved as a .tres
## file.
##
## Every node belongs to a Street (via `street_id`) and sits on one of
## its two directional sidewalks (via `side`):
##   side == 0 (even / pair)  → FORWARD walking direction
##   side == 1 (odd  / impair) → REVERSE walking direction
## Same parity across different streets means the same physical
## walking direction; opposite parity means the reverse direction.
## See Street.gd for the full Parisian pavement rules.
##
## TODO: will support Paris-district topology — nodes may belong to
##       different streets with their own visual themes and gameplay
##       rules.
class_name BoardNode
extends Resource

## Unique identifier (e.g. &"cell_0", &"rivoli_even_3").
@export var id: StringName = &""

## World position in LoopBoard local space.
@export var position: Vector2 = Vector2.ZERO

## Which street this node belongs to (e.g. &"loop", &"rue_de_rivoli").
@export var street_id: StringName = &""

## Which sidewalk of the street: 0 = even/pair (forward direction),
## 1 = odd/impair (reverse direction).
@export var side: int = 0

## If non-empty, this node is a shop anchor. The shop_id matches an
## entry in CatalogManager / data/shops/*.tres.
@export var shop_id: StringName = &""

## Directed adjacency: the node IDs reachable in one step from this
## node.  A simple loop has exactly one next node; intersections have
## two or more.
@export var next_nodes: Array[StringName] = []

## 1-based display number for HUD (matches the board visual
## labelling).
@export var display_index: int = 0
