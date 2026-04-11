class_name Product
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D = null
## Foreign key → Shop.id. Validated by CatalogManager on load.
@export var shop_id: StringName = &""
@export var base_price: int = 0
@export var weight: float = 1.0
@export var tags: Array[StringName] = []
