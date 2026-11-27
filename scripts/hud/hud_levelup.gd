class_name HudLevelUp
extends HudWindow
## Окно прокачки: три карточки и три вида выбора — улучшение, 5-й уровень, заклинание.

# ── Узлы окна: заголовок, три карточки и кнопка переброса.
@onready var title_label: Label = $VBox/Title
@onready var button_1: Button = $VBox/UpgradeButton1
@onready var button_2: Button = $VBox/UpgradeButton2
@onready var button_3: Button = $VBox/UpgradeButton3
@onready var reroll_button: Button = $VBox/RerollButton

# ── Состояние окна: что показано и какой выбор сейчас открыт.
## Карточки улучшений, показанные сейчас.
var current_choices: Array = []
## Заклинания, показанные сейчас.
var current_spells: Array = []
## Открыт выбор заклинания (а не карточки улучшения).
var choosing_spell: bool = false
## Открыт выбор 5-го уровня: заклинание или усиление урона.
var choosing_level5: bool = false

func _ready() -> void:
	button_1.pressed.connect(_on_card_pressed.bind(0))
	button_2.pressed.connect(_on_card_pressed.bind(1))
	button_3.pressed.connect(_on_card_pressed.bind(2))
	reroll_button.pressed.connect(_on_reroll_pressed)

# ── Три вида выбора: обычное улучшение, 5-й уровень, заклинание.
func show_upgrades(choices: Array, title: String = "Уровень повышен! Выбери улучшение:") -> void:
	choosing_spell = false
	choosing_level5 = false
	current_choices = choices
	_fill(choices, Loc.t(title))
	button_1.grab_focus()

## Пятый уровень: один выбор из трёх. Усиление урона стоит в центре (кнопка №2),
## чтобы его нельзя было спутать с заклинаниями по краям.
func show_level5(choices: Array) -> void:
	choosing_spell = false
	choosing_level5 = true
	current_choices = choices
	_fill(choices, Loc.t("Новое заклинание или усиление:"))
	# В фокус — центральная карточка (усиление), если она есть.
	if choices.size() > 1:
		button_2.grab_focus()
	else:
		button_1.grab_focus()

func show_spells(spells: Array) -> void:
	choosing_spell = true
	choosing_level5 = false
	current_spells = spells
	_fill(spells, Loc.t("Новое заклинание! Выбери:"))
	button_1.grab_focus()

# ── Общая часть трёх видов выбора: заголовок, тексты карточек, показ окна.
func _fill(cards: Array, title_text: String) -> void:
	title_label.text = title_text
	var buttons: Array = [button_1, button_2, button_3]
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		if i < cards.size():
			button.visible = true
			button.text = "%s\n%s" % [Loc.t(str(cards[i]["title"])), Loc.t(str(cards[i]["desc"]))]
		else:
			button.visible = false
	fit()
	visible = true

# ── Нажатие карточки: выбор уходит сигналами диспетчера — их слушает main.gd.
func _on_card_pressed(index: int) -> void:
	click()
	if choosing_level5:
		if index < current_choices.size():
			var card: Dictionary = current_choices[index]
			var card_id: String = str(card["id"])
			hide()
			if str(card.get("kind", "")) == "spell":
				hud.spell_chosen.emit(card_id)
			else:
				hud.level5_chosen.emit(card_id)
		return
	if choosing_spell:
		if index < current_spells.size():
			var spell_id: String = str(current_spells[index]["id"])
			hide()
			hud.spell_chosen.emit(spell_id)
		return
	if index < current_choices.size():
		var upgrade_id: String = str(current_choices[index]["id"])
		hide()
		hud.upgrade_chosen.emit(upgrade_id)

# ── Кнопка переброса: цена и доступность по золоту.
func update_reroll_cost(cost: int, gold: int) -> void:
	reroll_button.text = Loc.t("Перебросить (%d золота)") % cost
	reroll_button.disabled = gold < cost

func set_reroll_hint(text: String) -> void:
	reroll_button.text = text

func _on_reroll_pressed() -> void:
	click()
	hud.reroll_requested.emit()
