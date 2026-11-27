extends CanvasLayer
## HUD: полосы опыта и HP, таймер, счётчики, надписи по центру и три окна.

# ── Сигналы в Main: выбранная карточка, рестарт, выход в меню, реролл.
signal upgrade_chosen(upgrade_id: String)
signal restart_requested
signal menu_requested
signal spell_chosen(spell_id: String)
signal level5_chosen(card_id: String)
signal continue_endless_requested
signal victory_menu_requested
signal reroll_requested

# ── Состояние HUD: пауза, время и убийства для отчёта, твин надписи, окно FPS.
var is_paused: bool = false
var cached_time: float = 0.0
var cached_kills: int = 0
var announce_tween: Tween = null
var fps_timer: float = 0.0
var fps_frames: int = 0

## Что выбирает игрок прямо сейчас — эти флаги читает main.gd, живут они в окне прокачки.
var choosing_spell: bool:
	get:
		return bool(level_up_window.choosing_spell)

var choosing_level5: bool:
	get:
		return bool(level_up_window.choosing_level5)

# ── Узлы HUD: верхняя панель и надпись по центру.
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var gold_label: Label = $TopLeft/GoldLabel
@onready var timer_label: Label = $TopCenter/TimerLabel
@onready var boss_label: Label = $TopCenter/BossLabel
@onready var boss_bar: ProgressBar = $TopCenter/BossBar
@onready var kills_label: Label = $TopRight/KillsLabel
@onready var fps_label: Label = $TopRight/FPSLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var difficulty_label: Label = $DifficultyLabel
@onready var stats_label: Label = $StatsLabel
@onready var wave_label: Label = $WaveLabel
@onready var dimmer: ColorRect = $Dimmer

# ── Окна HUD: у каждого свой скрипт, диспетчер только показывает и прячет их.
@onready var level_up_window: HudLevelUp = $LevelUpPanel
@onready var results_window: HudResults = $ResultsPanel
@onready var pause_window: HudPause = $PausePanel

# ── Старт: перевод, масштаб интерфейса, подписка на игрока, строка сложности.
func _ready() -> void:
	Loc.translate_tree(self)
	UIScale.apply(self)
	# Окна получают ссылку на диспетчер: через неё шлют сигналы и закрывают паузу.
	level_up_window.hud = self
	results_window.hud = self
	pause_window.hud = self
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

# ── Кадр интерфейса: затемнение под окнами и счётчик FPS.
func _process(delta: float) -> void:
	dimmer.visible = level_up_window.visible or results_window.visible or pause_window.visible
	_update_fps_counter(delta)

## Счётчик кадров: считаем сами за окно 0.25 с — так цифра честная и не дёргается
## (Engine.get_frames_per_second() усредняет за секунду и запаздывает).
## Цвет показывает состояние: зелёный — плавно, жёлтый — заметно, красный — тяжело.
# ── Счётчик FPS: своё окно 0.25 с, цвет — по нагрузке (зелёный / жёлтый / красный).
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

# ── Сигналы игрока: HP, опыт и характеристики (в бою скрыты, живут в паузе).
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

# ── Верхняя панель: таймер, золото, счётчик убийств.
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

# ── Окно прокачки: обёртки для main.gd, само окно живёт в hud_levelup.gd.
func show_level_up(choices: Array, title: String = "Уровень повышен! Выбери улучшение:") -> void:
	level_up_window.show_upgrades(choices, title)

func show_level5_choices(choices: Array) -> void:
	level_up_window.show_level5(choices)

func show_spell_choices(spells: Array) -> void:
	level_up_window.show_spells(spells)

func hide_level_up() -> void:
	level_up_window.hide()

func update_reroll_cost(cost: int, gold: int) -> void:
	level_up_window.update_reroll_cost(cost, gold)

func set_reroll_hint(text: String) -> void:
	level_up_window.set_reroll_hint(text)

# ── Экран результатов: обёртки для main.gd, сам экран живёт в hud_results.gd.
func show_game_over(elapsed: float, kills: int, level: int, is_new_record: bool = false) -> void:
	results_window.show_game_over(elapsed, kills, level, is_new_record)

func show_results(is_victory: bool, elapsed: float, kills: int, level: int, is_new_record: bool = false) -> void:
	results_window.show_results(is_victory, elapsed, kills, level, is_new_record)

func show_victory(elapsed: float, kills: int, level: int) -> void:
	results_window.show_victory(elapsed, kills, level)

func hide_victory() -> void:
	results_window.hide()

# ── Ввод: Esc, P и Start открывают и закрывают паузу.
func _input(event: InputEvent) -> void:
	# Действие "pause": Esc, P и кнопка Start на геймпаде.
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

# ── Пауза: не открывается поверх прокачки и экрана результатов.
func toggle_pause() -> void:
	if level_up_window.visible or results_window.visible:
		return
	if is_paused:
		close_pause()
	else:
		open_pause()

func open_pause() -> void:
	is_paused = true
	pause_window.visible = true
	pause_window.show_report(cached_time, cached_kills)
	get_tree().paused = true

func close_pause() -> void:
	is_paused = false
	pause_window.visible = false
	get_tree().paused = false

# ── Отчёт в паузе (окно паузы строит его само из времени и убийств).
func refresh_pause_stats() -> void:
	pause_window.show_report(cached_time, cached_kills)

# ── Полоса HP босса и мини-босса.
func show_boss_bar() -> void:
	boss_label.visible = true
	boss_bar.visible = true

func update_boss_bar(current_hp: int, maximum_hp: int) -> void:
	boss_bar.max_value = maximum_hp
	boss_bar.value = current_hp

func hide_boss_bar() -> void:
	boss_label.visible = false
	boss_bar.visible = false

# ── Крупная надпись по центру: держится 1.4 с и плавно гаснет.
func announce(text: String, color: Color = Color(1.0, 1.0, 1.0), font_size: int = 34) -> void:
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
