extends CanvasLayer
## Интерфейс: HP, опыт, таймер, меню улучшений, экран поражения.

signal upgrade_chosen(upgrade_id: String)
signal restart_requested
signal menu_requested
signal spell_chosen(spell_id: String)
signal level5_chosen(card_id: String)
signal continue_endless_requested
signal victory_menu_requested
signal reroll_requested

var current_choices: Array = []
var current_spells: Array = []
var choosing_spell: bool = false
## Панель 5-го уровня: два заклинания и усиление урона в центре.
var choosing_level5: bool = false
var is_paused: bool = false
var cached_time: float = 0.0
var cached_kills: int = 0
var announce_tween: Tween = null
var fps_timer: float = 0.0
var fps_frames: int = 0

@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var timer_label: Label = $TopCenter/TimerLabel
@onready var kills_label: Label = $TopRight/KillsLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var stats_label: Label = $StatsLabel
@onready var difficulty_label: Label = $DifficultyLabel
@onready var level_up_panel: PanelContainer = $LevelUpPanel
@onready var level_up_title: Label = $LevelUpPanel/VBox/Title
@onready var upgrade_button_1: Button = $LevelUpPanel/VBox/UpgradeButton1
@onready var upgrade_button_2: Button = $LevelUpPanel/VBox/UpgradeButton2
@onready var upgrade_button_3: Button = $LevelUpPanel/VBox/UpgradeButton3
@onready var results_panel: PanelContainer = $ResultsPanel
@onready var results_title: Label = $ResultsPanel/VBox/Title
@onready var results_subtitle: Label = $ResultsPanel/VBox/Subtitle
@onready var new_record_label: Label = $ResultsPanel/VBox/RecordLabel
@onready var time_value: Label = $ResultsPanel/VBox/StatsRow/TimeValue
@onready var kills_value: Label = $ResultsPanel/VBox/StatsRow/KillsValue
@onready var level_value: Label = $ResultsPanel/VBox/StatsRow/LevelValue
@onready var gold_value: Label = $ResultsPanel/VBox/StatsRow/GoldValue
@onready var damage_rows: VBoxContainer = $ResultsPanel/VBox/Scroll/Body/DamageRows
@onready var build_rows: VBoxContainer = $ResultsPanel/VBox/Scroll/Body/BuildRows
@onready var boss_info: Label = $ResultsPanel/VBox/BossInfo
@onready var restart_button: Button = $ResultsPanel/VBox/Buttons/RestartButton
@onready var results_continue_button: Button = $ResultsPanel/VBox/Buttons/ContinueButton
@onready var menu_button: Button = $ResultsPanel/VBox/Buttons/MenuButton
@onready var gold_label: Label = $TopLeft/GoldLabel
@onready var boss_label: Label = $TopCenter/BossLabel
@onready var boss_bar: ProgressBar = $TopCenter/BossBar
@onready var wave_label: Label = $WaveLabel
@onready var reroll_button: Button = $LevelUpPanel/VBox/RerollButton
@onready var pause_panel: PanelContainer = $PausePanel
@onready var pause_stats: Label = $PausePanel/VBox/PauseStats
@onready var pause_continue_button: Button = $PausePanel/VBox/PauseContinueButton
@onready var pause_restart_button: Button = $PausePanel/VBox/PauseRestartButton
@onready var pause_menu_button: Button = $PausePanel/VBox/PauseMenuButton
@onready var dimmer: ColorRect = $Dimmer
@onready var build_stats: Label = $PausePanel/VBox/BuildScroll/BuildStats
@onready var controls_label: Label = $PausePanel/VBox/ControlsLabel
@onready var fps_label: Label = $TopRight/FPSLabel

func _ready() -> void:
	Loc.translate_tree(self)
	UIScale.apply(self)
	upgrade_button_1.pressed.connect(_on_upgrade_button_pressed.bind(0))
	upgrade_button_2.pressed.connect(_on_upgrade_button_pressed.bind(1))
	upgrade_button_3.pressed.connect(_on_upgrade_button_pressed.bind(2))
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	results_continue_button.pressed.connect(_on_victory_continue_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	pause_continue_button.pressed.connect(_on_pause_continue_pressed)
	pause_restart_button.pressed.connect(_on_restart_pressed)
	pause_menu_button.pressed.connect(_on_menu_pressed)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.connect("hp_changed", _on_hp_changed)
		player.connect("xp_changed", _on_xp_changed)
		player.connect("stats_changed", _on_stats_changed)
		_on_stats_changed()
	update_gold(Records.gold)
	var difficulty_color: Color = Color(0.55, 0.85, 1.0)
	if Records.selected_difficulty == "easy":
		difficulty_color = Color(0.6, 0.95, 0.6)
	elif Records.selected_difficulty == "hard":
		difficulty_color = Color(1.0, 0.45, 0.4)
	difficulty_label.text = "Сложность: %s · Карта: %s" % [Records.difficulty_name(), Records.map_name()]
	difficulty_label.modulate = difficulty_color

## Затемнение нужно всегда, когда открыто хоть одно окно поверх игры.
## Панель по размеру содержимого, по центру. Масштаб интерфейса может её увеличить,
## поэтому подгоняем каждый раз перед показом.
func _fit(panel: Control) -> void:
	UIScale.fit_panel(panel, get_viewport().get_visible_rect().size)

func _process(delta: float) -> void:
	dimmer.visible = level_up_panel.visible or results_panel.visible or pause_panel.visible
	_update_fps_counter(delta)

## Счётчик кадров: считаем сами за окно 0.25 с — так цифра честная и не дёргается
## (Engine.get_frames_per_second() усредняет за секунду и запаздывает).
## Цвет показывает состояние: зелёный — плавно, жёлтый — заметно, красный — тяжело.
func _update_fps_counter(delta: float) -> void:
	if not Records.settings_fps:
		fps_label.visible = false
		fps_timer = 0.0
		fps_frames = 0
		return
	fps_label.visible = true
	fps_timer += delta
	fps_frames += 1
	if fps_timer < 0.25:
		return
	var fps: int = int(round(float(fps_frames) / fps_timer))
	fps_timer = 0.0
	fps_frames = 0
	fps_label.text = "FPS %d" % fps
	if fps >= 50:
		fps_label.add_theme_color_override("font_color", Color(0.68, 0.88, 0.72))
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	else:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))

func _on_hp_changed(current_hp: int, maximum_hp: int) -> void:
	hp_bar.max_value = maximum_hp
	hp_bar.value = current_hp
	hp_label.text = "HP %d / %d" % [current_hp, maximum_hp]

func _on_xp_changed(current_xp: int, xp_next: int, level: int) -> void:
	xp_bar.max_value = xp_next
	xp_bar.value = current_xp
	level_label.text = Loc.t("Уровень %d") % level

func _on_stats_changed() -> void:
	# Характеристики в бою больше не висят на экране: они переехали в меню паузы.
	stats_label.visible = false
	stats_label.text = ""

func update_timer(elapsed: float) -> void:
	cached_time = elapsed
	var total_seconds: int = int(elapsed)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func update_gold(amount: int) -> void:
	gold_label.text = Loc.t("Золото: %d") % amount

func update_kills(kills: int) -> void:
	cached_kills = kills
	kills_label.text = Loc.t("Убийств: %d") % kills

func show_level_up(choices: Array, title: String = "Уровень повышен! Выбери улучшение:") -> void:
	choosing_spell = false
	choosing_level5 = false
	level_up_title.text = Loc.t(title)
	current_choices = choices
	var buttons: Array = [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		if i < choices.size():
			button.visible = true
			button.text = "%s\n%s" % [Loc.t(str(choices[i]["title"])), Loc.t(str(choices[i]["desc"]))]
		else:
			button.visible = false
	_fit(level_up_panel)
	level_up_panel.visible = true
	upgrade_button_1.grab_focus()

## Пятый уровень: один выбор из трёх. Усиление урона стоит в центре (кнопка №2),
## чтобы его нельзя было спутать с заклинаниями по краям.
func show_level5_choices(choices: Array) -> void:
	choosing_spell = false
	choosing_level5 = true
	current_choices = choices
	level_up_title.text = Loc.t("Новое заклинание или усиление:")
	var buttons: Array = [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		if i < choices.size():
			button.visible = true
			button.text = "%s\n%s" % [Loc.t(str(choices[i]["title"])), Loc.t(str(choices[i]["desc"]))]
		else:
			button.visible = false
	_fit(level_up_panel)
	level_up_panel.visible = true
	# В фокус — центральная карточка (усиление), если она есть.
	if choices.size() > 1:
		upgrade_button_2.grab_focus()
	else:
		upgrade_button_1.grab_focus()

func show_spell_choices(spells: Array) -> void:
	choosing_spell = true
	choosing_level5 = false
	current_spells = spells
	level_up_title.text = Loc.t("Новое заклинание! Выбери:")
	var buttons: Array = [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		if i < spells.size():
			button.visible = true
			button.text = "%s\n%s" % [Loc.t(str(spells[i]["title"])), Loc.t(str(spells[i]["desc"]))]
		else:
			button.visible = false
	_fit(level_up_panel)
	level_up_panel.visible = true
	upgrade_button_1.grab_focus()

func hide_level_up() -> void:
	level_up_panel.visible = false

func _on_upgrade_button_pressed(index: int) -> void:
	AudioManager.play("click", -8.0)
	if choosing_level5:
		if index < current_choices.size():
			var card: Dictionary = current_choices[index]
			var card_id: String = str(card["id"])
			level_up_panel.visible = false
			if str(card.get("kind", "")) == "spell":
				spell_chosen.emit(card_id)
			else:
				level5_chosen.emit(card_id)
		return
	if choosing_spell:
		if index < current_spells.size():
			var spell_id: String = str(current_spells[index]["id"])
			level_up_panel.visible = false
			spell_chosen.emit(spell_id)
		return
	if index < current_choices.size():
		var upgrade_id: String = str(current_choices[index]["id"])
		level_up_panel.visible = false
		upgrade_chosen.emit(upgrade_id)

# Источники: [id, цвет] — те же цвета, что у снарядов в бою.
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

var _results_victory: bool = false

func show_game_over(elapsed: float, kills: int, level: int, is_new_record: bool = false) -> void:
	show_results(false, elapsed, kills, level, is_new_record)

func show_results(is_victory: bool, elapsed: float, kills: int, level: int, is_new_record: bool = false) -> void:
	_results_victory = is_victory
	results_title.text = Loc.t("Победа!") if is_victory else Loc.t("Ты погиб...")
	results_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_victory else Color(1.0, 0.45, 0.45))
	if is_victory:
		results_subtitle.text = Loc.t("Ты продержался 10 минут! Арена покорена.") + "  ·  " + Loc.t("Сложность: %s") % Records.difficulty_name()
	else:
		results_subtitle.text = Loc.t("Сложность: %s") % Records.difficulty_name()
	time_value.text = Records.format_time(elapsed)
	kills_value.text = str(kills)
	level_value.text = str(level)
	gold_value.text = "+%d" % RunStats.gold_earned()
	new_record_label.visible = is_new_record
	_build_damage_rows()
	_build_build_rows()
	boss_info.text = _boss_context(elapsed)
	results_continue_button.visible = is_victory
	results_panel.visible = true
	# Подгоняем после сборки строк: содержимое меняет высоту панели.
	# Первый проход — сразу (чтобы панель не мигала), второй — следующим кадром:
	# минимальные размеры контейнеров пересчитываются только к концу кадра,
	# и на Крупном масштабе без второго прохода панель вылезает за экран.
	_fit(results_panel)
	_fit_next_frame()
	if is_victory:
		results_continue_button.grab_focus()
	else:
		restart_button.grab_focus()

func _fit_next_frame() -> void:
	await get_tree().process_frame
	if results_panel.visible:
		_fit(results_panel)

func _boss_context(elapsed: float) -> String:
	var spawn: float = RunStats.boss_spawn_time
	if RunStats.boss_killed_at >= 0.0:
		return Loc.t("Босс пришёл на %s и погиб через %s") % [Records.format_time(spawn), Records.format_time(RunStats.boss_killed_at - spawn)]
	if elapsed < spawn:
		return Loc.t("Босс появляется на %s — ты не дожил %s") % [Records.format_time(spawn), Records.format_time(spawn - elapsed)]
	return Loc.t("Босс пришёл на %s и остался жив") % Records.format_time(spawn)

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

func _evolution_of(weapon_id: String, evolutions: Array) -> String:
	for evo_id in evolutions:
		var def: Dictionary = WeaponData.weapon_of_evolution(str(evo_id))
		if str(def.get("id", "")) == weapon_id:
			return Loc.t(WeaponData.evolution_name(str(evo_id)))
	return ""

func _on_restart_pressed() -> void:
	AudioManager.play("click", -8.0)
	restart_requested.emit()

func _on_menu_pressed() -> void:
	AudioManager.play("click", -8.0)
	# После победы путь выхода другой: забег уже закрыт, нужно только сохранить рекорд.
	if _results_victory:
		victory_menu_requested.emit()
	else:
		menu_requested.emit()

func _input(event: InputEvent) -> void:
	# Действие "pause": Esc, P и кнопка Start на геймпаде.
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	# Не открываем паузу поверх прокачки или экрана поражения.
	if level_up_panel.visible or results_panel.visible:
		return
	is_paused = not is_paused
	pause_panel.visible = is_paused
	if is_paused:
		refresh_pause_stats()
		# Подгоняем после заполнения текста: отчёт о сборке меняет высоту панели.
		_fit(pause_panel)
		# Фокус на первую кнопку — чтобы геймпад сразу мог продолжить игру.
		pause_continue_button.grab_focus()
	get_tree().paused = is_paused

func refresh_pause_stats() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var level: int = int(player.get("level")) if player != null else 1
	var total_seconds: int = int(cached_time)
	pause_stats.text = Loc.t("Время: %02d:%02d   •   Убийств: %d   •   Уровень: %d") % [total_seconds / 60, total_seconds % 60, cached_kills, level]
	# Управление — только здесь, в бою подсказок нет.
	controls_label.text = "\n".join(PackedStringArray([
		Loc.t("Управление"),
		Loc.t("Движение — WASD / стрелки / стик"),
		Loc.t("Пауза — Esc / P / Start"),
		Loc.t("Выбор — стрелки / крестовина, подтвердить — Enter / A, назад — Esc / B"),
	]))
	# Полный список только того, что реально есть у игрока.
	if player != null and player.has_method("build_report"):
		build_stats.text = str(player.call("build_report"))
	else:
		build_stats.text = "—"

func _on_pause_continue_pressed() -> void:
	AudioManager.play("click", -8.0)
	is_paused = false
	pause_panel.visible = false
	get_tree().paused = false

func show_boss_bar() -> void:
	boss_label.visible = true
	boss_bar.visible = true

func update_boss_bar(current_hp: int, maximum_hp: int) -> void:
	boss_bar.max_value = maximum_hp
	boss_bar.value = current_hp

func hide_boss_bar() -> void:
	boss_label.visible = false
	boss_bar.visible = false

func announce(text: String, color: Color = Color(1.0, 1.0, 1.0), font_size: int = 34) -> void:
	# Крупная надпись по центру, которая держится 1.4 с и плавно гаснет.
	wave_label.text = text
	wave_label.add_theme_color_override("font_color", color)
	wave_label.add_theme_font_size_override("font_size", UIScale.font(font_size))
	wave_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	wave_label.visible = true
	if announce_tween != null and announce_tween.is_valid():
		announce_tween.kill()
	announce_tween = create_tween()
	announce_tween.tween_interval(1.4)
	announce_tween.tween_property(wave_label, "modulate:a", 0.0, 0.7)
	announce_tween.tween_callback(_hide_wave_label)

func _hide_wave_label() -> void:
	wave_label.visible = false

func set_boss_name(boss_name: String) -> void:
	boss_label.text = boss_name

func update_reroll_cost(cost: int, gold: int) -> void:
	reroll_button.text = Loc.t("Перебросить (%d золота)") % cost
	reroll_button.disabled = gold < cost

func set_reroll_hint(text: String) -> void:
	reroll_button.text = text

func _on_reroll_pressed() -> void:
	AudioManager.play("click", -8.0)
	reroll_requested.emit()

func show_victory(elapsed: float, kills: int, level: int) -> void:
	show_results(true, elapsed, kills, level, false)

func hide_victory() -> void:
	results_panel.visible = false

func _on_victory_continue_pressed() -> void:
	AudioManager.play("click", -8.0)
	results_panel.visible = false
	continue_endless_requested.emit()
