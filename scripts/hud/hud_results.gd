class_name HudResults
extends HudWindow
## Экран результатов: победа или смерть, разбор урона, сборка забега и кнопки.

# ── Узлы окна: заголовок, плитки с цифрами, списки разбора и кнопки.
@onready var title_label: Label = $VBox/Title
@onready var subtitle: Label = $VBox/Subtitle
@onready var new_record_label: Label = $VBox/RecordLabel
@onready var time_value: Label = $VBox/StatsRow/TimeValue
@onready var kills_value: Label = $VBox/StatsRow/KillsValue
@onready var level_value: Label = $VBox/StatsRow/LevelValue
@onready var gold_value: Label = $VBox/StatsRow/GoldValue
@onready var damage_rows: VBoxContainer = $VBox/Scroll/Body/DamageRows
@onready var build_rows: VBoxContainer = $VBox/Scroll/Body/BuildRows
@onready var boss_info: Label = $VBox/BossInfo
@onready var restart_button: Button = $VBox/Buttons/RestartButton
@onready var continue_button: Button = $VBox/Buttons/ContinueButton
@onready var menu_button: Button = $VBox/Buttons/MenuButton

# ── Цвета источников урона: те же, что у снарядов в бою.
const SOURCE_COLORS := {
	"bolt": Color(0.62, 0.78, 1.0),
	"orbit": Color(0.88, 0.92, 0.98),
	"nova": Color(1.0, 0.76, 0.36),
	"chain": Color(0.72, 0.82, 1.0),
	"fireball": Color(1.0, 0.5, 0.22),
	"frost": Color(0.62, 0.9, 1.0),
	"boomerang": Color(0.92, 0.86, 0.5),
	"spear": Color(0.76, 0.86, 0.7),
	"mine": Color(1.0, 0.62, 0.42),
	"poison": Color(0.52, 0.9, 0.42),
	"saw": Color(0.86, 0.86, 0.86),
	"traps": Color(1.0, 0.42, 0.42),
	"other": Color(0.7, 0.7, 0.7),
}

## Забег закончился победой — от этого зависит, какой сигнал выхода в меню слать.
var _victory: bool = false

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

# ── Показ экрана: победа или смерть.
func show_game_over(elapsed: float, kills: int, level: int, is_new_record: bool = false) -> void:
	show_results(false, elapsed, kills, level, is_new_record)

func show_results(is_victory: bool, elapsed: float, kills: int, level: int, is_new_record: bool = false) -> void:
	_victory = is_victory
	title_label.text = Loc.t("Победа!") if is_victory else Loc.t("Ты погиб...")
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_victory else Color(1.0, 0.45, 0.45))
	if is_victory:
		subtitle.text = Loc.t("Ты продержался 10 минут! Арена покорена.") + "  ·  " + Loc.t("Сложность: %s") % Records.difficulty_name()
	else:
		subtitle.text = Loc.t("Сложность: %s") % Records.difficulty_name()
	time_value.text = Records.format_time(elapsed)
	kills_value.text = str(kills)
	level_value.text = str(level)
	gold_value.text = "+%d" % RunStats.gold_earned()
	new_record_label.visible = is_new_record
	_build_damage_rows()
	_build_build_rows()
	boss_info.text = _boss_context(elapsed)
	continue_button.visible = is_victory
	visible = true
	# Подгоняем после сборки строк: содержимое меняет высоту панели.
	# Первый проход — сразу (чтобы панель не мигала), второй — следующим кадром:
	# минимальные размеры контейнеров пересчитываются только к концу кадра,
	# и на Крупном масштабе без второго прохода панель вылезает за экран.
	fit()
	_fit_next_frame()
	if is_victory:
		continue_button.grab_focus()
	else:
		restart_button.grab_focus()

# ── Победа: тот же экран, но с переходом в бесконечный режим.
func show_victory(elapsed: float, kills: int, level: int) -> void:
	show_results(true, elapsed, kills, level, false)

# ── Второй проход раскладки: контейнеры пересчитывают размеры только к концу кадра.
func _fit_next_frame() -> void:
	await get_tree().process_frame
	if visible:
		fit()

# ── Строка про босса: когда пришёл, убит ли и сколько прожил.
func _boss_context(elapsed: float) -> String:
	var spawn: float = RunStats.boss_spawn_time
	if RunStats.boss_killed_at >= 0.0:
		return Loc.t("Босс пришёл на %s и погиб через %s") % [Records.format_time(spawn), Records.format_time(RunStats.boss_killed_at - spawn)]
	if elapsed < spawn:
		return Loc.t("Босс появляется на %s — ты не дожил %s") % [Records.format_time(spawn), Records.format_time(spawn - elapsed)]
	return Loc.t("Босс пришёл на %s и остался жив") % Records.format_time(spawn)

# ── Помощники строк результатов: очистка списка, маркер цвета, подпись, полоска доли.
func _clear_rows(box: VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _source_color(id: String) -> Color:
	return SOURCE_COLORS.get(id, SOURCE_COLORS["other"])

func _swatch(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(10, 10)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

func _row_label(text: String, size: int, expand: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
	return label

# ── Разбор урона: топ-3 источника и «остальное» с долями.
func _build_damage_rows() -> void:
	_clear_rows(damage_rows)
	var entries: Array = RunStats.top_sources(3)
	var total: int = RunStats.total_damage()
	if entries.is_empty() or total <= 0:
		damage_rows.add_child(_row_label(Loc.t("Урона не было"), 14, true))
		return
	for entry in entries:
		damage_rows.add_child(_damage_row(str(entry["id"]), str(entry["name"]), int(entry["damage"]), float(entry["share"])))
	var rest: int = RunStats.rest_damage(3)
	if rest > 0:
		damage_rows.add_child(_damage_row("other", Loc.t("остальное"), rest, float(rest) / float(total)))

func _damage_row(id: String, title: String, damage: int, share: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_swatch(_source_color(id)))
	row.add_child(_row_label(title, 14, true))
	row.add_child(_row_label(str(damage), 13, false))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 100.0
	bar.value = share * 100.0
	bar.show_percentage = false
	# Полоска красится в цвет источника — по ней видно вклад с одного взгляда.
	var fill := StyleBoxFlat.new()
	fill.bg_color = _source_color(id)
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	row.add_child(bar)
	var pct := _row_label("%d%%" % roundi(share * 100.0), 13, false)
	pct.custom_minimum_size = Vector2(42, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	return row

# ── Сборка забега: оружие с эволюциями и уровни пассивок.
func _build_build_rows() -> void:
	_clear_rows(build_rows)
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		build_rows.add_child(_row_label(Loc.t("Нет данных о сборке"), 14, true))
		return
	var weapons: Array = p.get("unlocked_weapons")
	var evolutions: Array = p.get("evolutions")
	if weapons.is_empty():
		build_rows.add_child(_row_label(Loc.t("Оружия нет"), 14, true))
	for id in weapons:
		var weapon_id: String = str(id)
		var line: String = Loc.t(WeaponData.title_of(weapon_id))
		var evo: String = _evolution_of(weapon_id, evolutions)
		if evo != "":
			line += "  ·  " + Loc.t("эволюция: %s") % evo
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_swatch(_source_color(weapon_id)))
		row.add_child(_row_label(line, 14, true))
		build_rows.add_child(row)
	var passive_levels: Dictionary = p.get("passive_levels")
	var parts: Array = []
	for passive_def in PassiveData.LIST:
		var pid: String = str(passive_def["id"])
		var lvl: int = int(passive_levels.get(pid, 0))
		if lvl > 0:
			parts.append("%s %d/%d" % [Loc.t(PassiveData.name_of(pid)), lvl, PassiveData.max_level(pid)])
	if not parts.is_empty():
		build_rows.add_child(_row_label(Loc.t("Пассивки: %s") % ", ".join(parts), 13, true))

# ── Поиск эволюции для конкретного оружия.
func _evolution_of(weapon_id: String, evolutions: Array) -> String:
	for evo_id in evolutions:
		var def: Dictionary = WeaponData.weapon_of_evolution(str(evo_id))
		if str(def.get("id", "")) == weapon_id:
			return Loc.t(WeaponData.evolution_name(str(evo_id)))
	return ""

# ── Кнопки окна: рестарт, выход в меню (после победы путь другой) и бесконечный режим.
func _on_restart_pressed() -> void:
	click()
	hud.restart_requested.emit()

func _on_menu_pressed() -> void:
	click()
	# После победы путь выхода другой: забег уже закрыт, нужно только сохранить рекорд.
	if _victory:
		hud.victory_menu_requested.emit()
	else:
		hud.menu_requested.emit()

func _on_continue_pressed() -> void:
	click()
	visible = false
	hud.continue_endless_requested.emit()
