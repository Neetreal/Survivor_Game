class_name MenuShop
extends MenuPanel
## Магазин постоянных улучшений за золото.

# ── Узлы окна: текущее золото и список покупок.
@onready var gold_label: Label = $VBox/ShopGoldLabel
@onready var shop_list: VBoxContainer = $VBox/Scroll/ShopList
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(back)

func open() -> void:
	build_shop_list()
	back_button.grab_focus()

# ── Список магазина: уровень, цена, «MAX» и недоступность без золота.
func build_shop_list() -> void:
	gold_label.text = Loc.t("Золото: %d") % Records.gold
	clear_list(shop_list)
	for def_data in Records.meta_definitions:
		var upgrade_id: String = str(def_data["id"])
		var level: int = Records.get_upgrade_level(upgrade_id)
		var max_level: int = int(def_data["max_level"])
		var cost: int = Records.upgrade_cost(upgrade_id)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		if cost < 0:
			button.text = "%s Lv.%d/%d — MAX\n%s" % [Loc.t(str(def_data["name"])), level, max_level, Loc.t(str(def_data["desc"]))]
			button.disabled = true
		else:
			button.text = Loc.t("%s Lv.%d/%d — %d золота\n%s") % [Loc.t(str(def_data["name"])), level, max_level, cost, Loc.t(str(def_data["desc"]))]
			button.disabled = Records.gold < cost
		button.pressed.connect(_on_buy_upgrade.bind(upgrade_id))
		shop_list.add_child(button)
	UIScale.apply(shop_list)

func _on_buy_upgrade(upgrade_id: String) -> void:
	if Records.buy_upgrade(upgrade_id):
		AudioManager.play("gem", -6.0)
		build_shop_list()
