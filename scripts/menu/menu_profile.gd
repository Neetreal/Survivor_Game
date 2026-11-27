class_name MenuProfile
extends MenuPanel
## Профиль: статистика за всё время и переход к достижениям.

# ── Узлы окна: блок статистики и кнопка достижений.
@onready var profile_stats: Label = $VBox/ProfileStats
@onready var achievements_button: Button = $VBox/AchievementsButton
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(back)
	achievements_button.pressed.connect(_on_achievements_pressed)

func open() -> void:
	build_profile()
	achievements_button.grab_focus()

func _on_achievements_pressed() -> void:
	click()
	menu.show_panel(menu.achievements_panel)

func format_play_time(total_seconds: float) -> String:
	var seconds: int = int(total_seconds)
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return Loc.t("%d ч %d мин") % [hours, minutes]
	return Loc.t("%d мин") % minutes

# ── Текст профиля: счётчики за всё время и число открытых заклинаний.
func build_profile() -> void:
	var data: Dictionary = Records.profile
	profile_stats.text = Loc.t("Всего забегов: %d\nВсего убийств: %d\nВремя в игре: %s\nЗаработано золота: %d\nЗолото сейчас: %d\nПобед: %d   ·   Поражений: %d\nЛюбимый герой: %s\nОткрыто заклинаний: %d / 7") % [
		int(data["total_runs"]),
		int(data["total_kills"]),
		format_play_time(float(data["total_time"])),
		int(data["total_gold"]),
		Records.gold,
		int(data["victories"]),
		int(data["deaths"]),
		Records.favorite_hero_name(),
		data["spells_seen"].size(),
	]
	achievements_button.text = Loc.t("Достижения (%d / %d)") % [Records.achievement_count(), Records.achievement_definitions.size()]
