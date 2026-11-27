class_name MenuAchievements
extends MenuPanel
## Список достижений: что открыто, что нет и сколько золота получено.

# ── Узлы окна: общий прогресс и список достижений.
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var achievements_list: VBoxContainer = $VBox/Scroll/AchievementsList
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

func open() -> void:
	build_list()
	back_button.grab_focus()

func _on_back_pressed() -> void:
	click()
	menu.show_panel(menu.profile_panel)

# ── Список достижений: отметка [+], описание, награда и общий прогресс.
func build_list() -> void:
	clear_list(achievements_list)
	var unlocked: int = 0
	var total: int = Records.achievement_definitions.size()
	for def in Records.achievement_definitions:
		var is_unlocked: bool = Records.is_achievement_unlocked(str(def["id"]))
		if is_unlocked:
			unlocked += 1
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(600, 0)
		label.add_theme_font_size_override("font_size", 14)
		var mark: String = "[+]" if is_unlocked else "[  ]"
		label.text = Loc.t("%s  %s — %s (+%d золота)") % [mark, Loc.t(str(def["name"])), Loc.t(str(def["desc"])), int(def["gold"])]
		label.modulate = Color(0.65, 0.95, 0.65) if is_unlocked else Color(0.7, 0.7, 0.7)
		achievements_list.add_child(label)
	UIScale.apply(achievements_list)
	progress_label.text = Loc.t("Открыто %d из %d · за достижения получено %d золота") % [unlocked, total, Records.achievement_reward_total()]
