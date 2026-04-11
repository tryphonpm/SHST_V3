extends PanelContainer

@onready var title_label: Label = $VBox/TitleLabel
@onready var items_container: VBoxContainer = $VBox/ItemsContainer
@onready var btn_close: Button = $VBox/BtnClose

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(func() -> void: visible = false)
	GameManager.product_purchased.connect(_on_product_purchased)

func show_for_player(player: PlayerData) -> void:
	_rebuild(player)
	visible = true

func _rebuild(player: PlayerData) -> void:
	title_label.text = "Shopping List — %s" % player.display_name

	for child in items_container.get_children():
		child.queue_free()

	for product_id in player.shopping_list:
		var row := HBoxContainer.new()

		var product := CatalogManager.get_product(product_id)

		# Icon placeholder
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		if product:
			var shop := CatalogManager.get_shop(product.shop_id)
			icon.color = shop.color if shop else Color.GRAY
		else:
			icon.color = Color.GRAY
		row.add_child(icon)

		# Product name
		var name_lbl := Label.new()
		name_lbl.text = product.display_name if product else str(product_id)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Check mark
		var check_lbl := Label.new()
		var collected: bool = product_id in player.collected_items
		check_lbl.text = "  ✓" if collected else "  —"
		check_lbl.add_theme_color_override(
			"font_color",
			Color.GREEN if collected else Color(1, 1, 1, 0.4)
		)
		row.add_child(check_lbl)

		items_container.add_child(row)

func _on_product_purchased(_player_id: int, _product_id: StringName) -> void:
	if visible:
		var current := TurnManager.get_current_player()
		if current:
			_rebuild(current)
