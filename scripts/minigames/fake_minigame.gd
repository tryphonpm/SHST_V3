extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var shop_label: Label = $Panel/VBox/ShopLabel

func setup(shop: Shop) -> void:
	if shop:
		shop_label.text = "Collecting from: %s" % shop.display_name
	else:
		shop_label.text = ""
