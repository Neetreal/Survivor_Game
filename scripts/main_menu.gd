extends Control
## Главное меню: Играть, Рекорды, Выход.

@onready var play_button: Button = $Center/VBox/PlayButton
@onready var records_button: Button = $Center/VBox/RecordsButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var play_panel: PanelContainer = $CharacterPanel
@onready var easy_button: Button = $CharacterPanel/VBox/DifficultyBox/EasyButton
@onready var normal_button: Button = $CharacterPanel/VBox/DifficultyBox/NormalButton
@onready var hard_button: Button = $CharacterPanel/VBox/DifficultyBox/HardButton
@onready var forest_button: Button = $CharacterPanel/VBox/MapBox/ForestButton
@onready var bog_button: Button = $CharacterPanel/VBox/MapBox/BogButton
@onready var arena_button: Button = $CharacterPanel/VBox/MapBox/ArenaButton
@onready var difficulty_desc: Label = $CharacterPanel/VBox/DifficultyDesc
@onready var start_button: Button = $CharacterPanel/VBox/StartButton
@onready var character_list: VBoxContainer = $CharacterPanel/VBox/Scroll/CharacterList
@onready var character_back_button: Button = $CharacterPanel/VBox/BackButton
@onready var shop_button: Button = $Center/VBox/ShopButton
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var shop_gold_label: Label = $ShopPanel/VBox/ShopGoldLabel
@onready var shop_list: VBoxContainer = $ShopPanel/VBox/Scroll/ShopList
@onready var shop_back_button: Button = $ShopPanel/VBox/BackButton
@onready var profile_button: Button = $Center/VBox/ProfileButton
@onready var profile_panel: PanelContainer = $ProfilePanel
@onready var profile_stats: Label = $ProfilePanel/VBox/ProfileStats
@onready var profile_achievements_button: Button = $ProfilePanel/VBox/AchievementsButton
@onready var profile_back_button: Button = $ProfilePanel/VBox/BackButton
@onready var achievements_panel: PanelContainer = $AchievementsPanel
@onready var achievements_progress: Label = $AchievementsPanel/VBox/ProgressLabel
@onready var achievements_list: VBoxContainer = $AchievementsPanel/VBox/Scroll/AchievementsList
@onready var achievements_back_button: Button = $AchievementsPanel/VBox/BackButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VBox/Columns/Left/VolumeSlider
@onready var windowed_button: Button = $SettingsPanel/VBox/Columns/Left/ScreenBox/WindowedButton
@onready var fullscreen_button: Button = $SettingsPanel/VBox/Columns/Left/ScreenBox/FullscreenButton
@onready var borderless_button: Button = $SettingsPanel/VBox/Columns/Left/ScreenBox/BorderlessButton
@onready var quality_low_button: Button = $SettingsPanel/VBox/Columns/Right/QualityBox/LowButton
@onready var quality_medium_button: Button = $SettingsPanel/VBox/Columns/Right/QualityBox/MediumButton
@onready var quality_high_button: Button = $SettingsPanel/VBox/Columns/Right/QualityBox/HighButton
@onready var fps_check: CheckButton = $SettingsPanel/VBox/Columns/Right/FpsCheck
@onready var lang_ru_button: Button = $SettingsPanel/VBox/Columns/Right/LanguageBox/RuButton
@onready var lang_en_button: Button = $SettingsPanel/VBox/Columns/Right/LanguageBox/EnButton
@onready var settings_back_button: Button = $SettingsPanel/VBox/BackButton
@onready var shake_normal_button: Button = $SettingsPanel/VBox/Columns/Left/ShakeBox/ShakeNormalButton
@onready var shake_low_button: Button = $SettingsPanel/VBox/Columns/Left/ShakeBox/ShakeLowButton
@onready var shake_off_button: Button = $SettingsPanel/VBox/Columns/Left/ShakeBox/ShakeOffButton
@onready var ui_small_button: Button = $SettingsPanel/VBox/Columns/Right/UIScaleBox/SmallButton
@onready var ui_normal_button: Button = $SettingsPanel/VBox/Columns/Right/UIScaleBox/NormalButton
@onready var ui_large_button: Button = $SettingsPanel/VBox/Columns/Right/UIScaleBox/LargeButton
@onready var reset_records_button: Button = $SettingsPanel/VBox/DangerBox/ResetRecordsButton
@onready var reset_progress_button: Button = $SettingsPanel/VBox/DangerBox/ResetProgressButton
@onready var confirm_panel: PanelContainer = $ConfirmPanel
@onready var confirm_title: Label = $ConfirmPanel/VBox/TitleLabel
@onready var confirm_desc: Label = $ConfirmPanel/VBox/DescLabel
@onready var confirm_buttons: HBoxContainer = $ConfirmPanel/VBox/Buttons
@onready var confirm_cancel_button: Button = $ConfirmPanel/VBox/Buttons/CancelButton
@onready var confirm_accept_button: Button = $ConfirmPanel/VBox/Buttons/AcceptButton
@onready var best_label: Label = $Center/VBox/BestLabel
@onready var records_panel: PanelContainer = $RecordsPanel
@onready var best_stats_label: Label = $RecordsPanel/VBox/BestStatsLabel
@onready var history_label: Label = $RecordsPanel/VBox/HistoryLabel
@onready var back_button: Button = $RecordsPanel/VBox/BackButton
@onready var menu_center: CenterContainer = $Center
@onready var dimmer: ColorRect = $Dimmer

## Все всплывающие окна меню. Видимым может быть только одно,
## иначе нижнее окно просвечивало сквозь верхнее.
var all_panels: Array[PanelContainer] = []
## Ширина текста в окне подтверждения при обычном масштабе. Нужна явно:
## у Label с переносом слов минимальная высота считается по текущей ширине,
## и при нулевой ширине окно раздувается на весь экран.
const CONFIRM_DESC_WIDTH: float = 560.0
## Размеры окна подтверждения: с предупреждением и с коротким итогом.
const CONFIRM_WARN_SIZE: Vector2 = Vector2(620.0, 330.0)
const CONFIRM_DONE_SIZE: Vector2 = Vector2(620.0, 226.0)
## Что подтверждаем: "records" (только рекорды) или "progress" (полный сброс).
var _confirm_kind: String = ""
## Окно уже показывает результат сброса — тогда кнопка называется «Ок».
var _confirm_done: bool = false

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	start_button.pressed.connect(_on_start_pressed)
	easy_button.pressed.connect(_on_difficulty_selected.bind("easy"))
	normal_button.pressed.connect(_on_difficulty_selected.bind("normal"))
	hard_button.pressed.connect(_on_difficulty_selected.bind("hard"))
	forest_button.pressed.connect(_on_map_selected.bind("forest"))
	bog_button.pressed.connect(_on_map_selected.bind("bog"))
	arena_button.pressed.connect(_on_map_selected.bind("arena"))
	character_back_button.pressed.connect(_on_play_back_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	profile_achievements_button.pressed.connect(_on_profile_achievements_pressed)
	profile_back_button.pressed.connect(_on_profile_back_pressed)
	achievements_back_button.pressed.connect(_on_achievements_back_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	reset_records_button.pressed.connect(_on_reset_records_pressed)
	reset_progress_button.pressed.connect(_on_reset_progress_pressed)
	confirm_cancel_button.pressed.connect(_on_confirm_cancel_pressed)
	confirm_accept_button.pressed.connect(_on_confirm_accept_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	windowed_button.pressed.connect(_on_screen_mode_selected.bind(0))
	fullscreen_button.pressed.connect(_on_screen_mode_selected.bind(1))
	borderless_button.pressed.connect(_on_screen_mode_selected.bind(2))
	quality_low_button.pressed.connect(_on_quality_selected.bind(0))
	quality_medium_button.pressed.connect(_on_quality_selected.bind(1))
	quality_high_button.pressed.connect(_on_quality_selected.bind(2))
	fps_check.toggled.connect(_on_fps_toggled)
	shake_normal_button.pressed.connect(_on_shake_selected.bind(0))
	shake_low_button.pressed.connect(_on_shake_selected.bind(1))
	shake_off_button.pressed.connect(_on_shake_selected.bind(2))
	ui_small_button.pressed.connect(_on_ui_scale_selected.bind(0))
	ui_normal_button.pressed.connect(_on_ui_scale_selected.bind(1))
	ui_large_button.pressed.connect(_on_ui_scale_selected.bind(2))
	lang_ru_button.pressed.connect(_on_language_selected.bind("ru"))
	lang_en_button.pressed.connect(_on_language_selected.bind("en"))
	records_button.pressed.connect(_on_records_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	shop_back_button.pressed.connect(_on_shop_back_pressed)
	# Локализация: переводим подписи сцены (русский — исходный текст).
	Loc.translate_tree(self)
	refresh_settings_ui()
	# Геймпад: фокус сразу на первой кнопке, дальше — крестовина/стик и A.
	play_button.grab_focus()
	AudioManager.play_music("menu")
	refresh_best_label()
	all_panels = [records_panel, play_panel, shop_panel, profile_panel, achievements_panel, settings_panel, confirm_panel]
	# Масштаб интерфейса — в самом конце, когда все списки уже собраны.
	UIScale.apply(self)
	# При изменении размера окна панели подгоняем заново.
	get_viewport().size_changed.connect(_on_viewport_resized)
	for panel in all_panels:
		panel.visible = false
	dimmer.visible = false

## Показать ровно одно окно: остальные гасим, меню под ними убираем.
func show_panel(target: PanelContainer) -> void:
	for panel in all_panels:
		panel.visible = (panel == target)
	menu_center.visible = false
	dimmer.visible = target != null
	# Панель подгоняем под содержимое и под экран (масштаб интерфейса может её увеличить).
	if target != null:
		UIScale.fit_panel(target, get_viewport().get_visible_rect().size)

## Закрыть все окна и вернуться к списку кнопок.
func close_panels() -> void:
	for panel in all_panels:
		panel.visible = false
	menu_center.visible = true
	dimmer.visible = false
	play_button.grab_focus()

## Esc закрывает текущее окно меню.
func _input(event: InputEvent) -> void:
	# Esc/B поверх окна подтверждения закрывает только его — настройки остаются.
	if event.is_action_pressed("ui_cancel") and confirm_panel.visible:
		AudioManager.play("click", -8.0)
		_on_confirm_cancel_pressed()
		get_viewport().set_input_as_handled()
		return
	# Esc или кнопка B на геймпаде закрывают открытое окно меню.
	if event.is_action_pressed("ui_cancel") and not menu_center.visible:
		AudioManager.play("click", -8.0)
		close_panels()
		get_viewport().set_input_as_handled()

func refresh_best_label() -> void:
	if Records.best_time > 0.0:
		best_label.text = Loc.t("Рекорд: %s • Убийств: %d • Уровень: %d") % [Records.format_time(Records.best_time), Records.best_kills, Records.best_level]
	else:
		best_label.text = Loc.t("Рекордов пока нет — сыграй первый забег!")

func _on_play_pressed() -> void:
	AudioManager.play("click", -8.0)
	build_character_list()
	refresh_difficulty_buttons()
	show_panel(play_panel)
	start_button.grab_focus()

func _on_quit_pressed() -> void:
	AudioManager.play("click", -8.0)
	get_tree().quit()

func _on_records_pressed() -> void:
	AudioManager.play("click", -8.0)
	if Records.best_time > 0.0:
		best_stats_label.text = Loc.t("Лучшее время: %s\nБольше всего убийств: %d\nМаксимальный уровень: %d") % [Records.format_time(Records.best_time), Records.best_kills, Records.best_level]
	else:
		best_stats_label.text = Loc.t("Рекордов пока нет.\nСыграй забег — и возвращайся сюда!")
	if Records.history.is_empty():
		history_label.text = Loc.t("Последние забеги:\n— пока пусто —")
	else:
		var text: String = Loc.t("Последние забеги:")
		for entry in Records.history:
			var date_str: String = str(entry.get("date", ""))
			if date_str.length() >= 16:
				date_str = date_str.substr(0, 10) + " " + date_str.substr(11, 5)
			text += Loc.t("\n%s — %s • Убийств: %d • Уровень: %d") % [date_str, Records.format_time(float(entry.get("time", 0.0))), int(entry.get("kills", 0)), int(entry.get("level", 1))]
		history_label.text = text
	show_panel(records_panel)
	back_button.grab_focus()

func _on_back_pressed() -> void:
	AudioManager.play("click", -8.0)
	close_panels()

func refresh_difficulty_buttons() -> void:
	var easy_name: String = Loc.t(str(Records.difficulty_definitions["easy"]["name"]))
	var normal_name: String = Loc.t(str(Records.difficulty_definitions["normal"]["name"]))
	var hard_name: String = Loc.t(str(Records.difficulty_definitions["hard"]["name"]))
	easy_button.text = ("▶ " + easy_name) if Records.selected_difficulty == "easy" else easy_name
	normal_button.text = ("▶ " + normal_name) if Records.selected_difficulty == "normal" else normal_name
	hard_button.text = ("▶ " + hard_name) if Records.selected_difficulty == "hard" else hard_name
	start_button.text = Loc.t("В бой! (%s)") % Records.difficulty_name()
	refresh_map_buttons()
	refresh_choice_info()

func refresh_map_buttons() -> void:
	forest_button.text = ("▶ " + Loc.t("Лес")) if Records.selected_map == "forest" else Loc.t("Лес")
	bog_button.text = ("▶ " + Loc.t("Топкие болота")) if Records.selected_map == "bog" else Loc.t("Топкие болота")
	arena_button.text = ("▶ " + Loc.t("Арена")) if Records.selected_map == "arena" else Loc.t("Арена")

func refresh_choice_info() -> void:
	difficulty_desc.text = Loc.t("%s\nКарта «%s»: %s") % [Records.difficulty_desc(), Records.map_name(), Records.map_desc()]

func _on_map_selected(map_id: String) -> void:
	AudioManager.play("click", -8.0)
	Records.set_map(map_id)
	refresh_map_buttons()
	refresh_choice_info()

func _on_start_pressed() -> void:
	AudioManager.play("click", -8.0)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_play_back_pressed() -> void:
	AudioManager.play("click", -8.0)
	close_panels()

func _on_difficulty_selected(difficulty_id: String) -> void:
	AudioManager.play("click", -8.0)
	Records.set_difficulty(difficulty_id)
	refresh_difficulty_buttons()

func _on_profile_pressed() -> void:
	AudioManager.play("click", -8.0)
	build_profile()
	show_panel(profile_panel)
	profile_achievements_button.grab_focus()

func _on_profile_back_pressed() -> void:
	AudioManager.play("click", -8.0)
	close_panels()

func _on_profile_achievements_pressed() -> void:
	AudioManager.play("click", -8.0)
	build_achievements_list()
	show_panel(achievements_panel)
	achievements_back_button.grab_focus()

func _on_achievements_back_pressed() -> void:
	AudioManager.play("click", -8.0)
	show_panel(profile_panel)

func format_play_time(total_seconds: float) -> String:
	var seconds: int = int(total_seconds)
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return Loc.t("%d ч %d мин") % [hours, minutes]
	return Loc.t("%d мин") % minutes

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
	profile_achievements_button.text = Loc.t("Достижения (%d / %d)") % [Records.achievement_count(), Records.achievement_definitions.size()]

func build_achievements_list() -> void:
	for child in achievements_list.get_children():
		achievements_list.remove_child(child)
		child.queue_free()
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
	achievements_progress.text = Loc.t("Открыто %d из %d · за достижения получено %d золота") % [unlocked, total, Records.achievement_reward_total()]

## Кнопка «Сбросить рекорды»: спрашиваем подтверждение, ничего не стирая сразу.
func _on_reset_records_pressed() -> void:
	AudioManager.play("click", -8.0)
	open_confirm("records")

## Кнопка «Сбросить весь прогресс»: то же, но предупреждение строже.
func _on_reset_progress_pressed() -> void:
	AudioManager.play("click", -8.0)
	open_confirm("progress")

## Показываем окно предупреждения. Ничего не меняем, пока не нажали «Сбросить».
func open_confirm(kind: String) -> void:
	_confirm_kind = kind
	_confirm_done = false
	confirm_cancel_button.visible = true
	confirm_accept_button.text = Loc.t("Сбросить")
	confirm_desc.custom_minimum_size = Vector2(CONFIRM_DESC_WIDTH * UIScale.factor(), 0.0)
	# Опасная кнопка занимает свою половину ряда, как и в других окнах.
	confirm_accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_accept_button.custom_minimum_size.x = 0.0
	confirm_buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	confirm_panel.set_meta("ui_scale_base_size", CONFIRM_WARN_SIZE)
	if kind == "records":
		confirm_title.text = Loc.t("Сбросить рекорды и историю?")
		confirm_desc.text = Loc.t("Пропадут:\n• лучшее время, убийства и уровень;\n• список последних забегов.\n\nЗолото, купленная прокачка, достижения и статистика профиля останутся.")
	else:
		confirm_title.text = Loc.t("Сбросить весь прогресс?")
		confirm_desc.text = Loc.t("Игра станет такой же, как при первом запуске.\n\nПропадут: золото, купленная прокачка, достижения, рекорды, история забегов и вся статистика профиля. Выбор героя, карты и сложности вернётся к стандартному.\n\nНастройки — звук, экран, язык, качество, масштаб — не изменятся.")
	show_panel(confirm_panel)
	UIScale.fit_panel(confirm_panel, get_viewport().get_visible_rect().size)
	# Фокус на «Отмене»: случайное нажатие A на геймпаде ничего не стирает.
	confirm_cancel_button.grab_focus()

## «Отмена» (или Esc): возвращаемся в настройки, данные не тронуты.
func _on_confirm_cancel_pressed() -> void:
	if _confirm_done:
		show_panel(settings_panel)
		settings_back_button.grab_focus()
		return
	show_panel(settings_panel)
	if _confirm_kind == "records":
		reset_records_button.grab_focus()
	else:
		reset_progress_button.grab_focus()

func _on_confirm_accept_pressed() -> void:
	if _confirm_done:
		_on_confirm_cancel_pressed()
		return
	if _confirm_kind == "records":
		Records.reset_records()
		AudioManager.play("gem", -8.0)
		refresh_best_label()
		_show_confirm_done(Loc.t("Рекорды сброшены"), Loc.t("Лучшее время, убийства, уровень и история забегов обнулены.\nЗолото, прокачка и достижения остались на месте."))
	else:
		Records.reset_progress()
		AudioManager.play("gem", -8.0)
		refresh_best_label()
		_show_confirm_done(Loc.t("Прогресс сброшен"), Loc.t("Золото, прокачка, достижения, рекорды и статистика обнулены — игра как при первом запуске.\nНастройки не изменились."))

## То же окно показывает итог: одна кнопка «Ок» и никакой опасной кнопки.
func _show_confirm_done(title: String, text: String) -> void:
	_confirm_done = true
	confirm_desc.custom_minimum_size = Vector2(CONFIRM_DESC_WIDTH * UIScale.factor(), 0.0)
	# В итоговом окне одна кнопка (узкая, по центру) и оно ниже — без пустоты.
	confirm_accept_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_accept_button.custom_minimum_size.x = 220.0 * UIScale.factor()
	confirm_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_panel.set_meta("ui_scale_base_size", CONFIRM_DONE_SIZE)
	confirm_title.text = title
	confirm_desc.text = text
	confirm_cancel_button.visible = false
	confirm_accept_button.text = Loc.t("Ок")
	show_panel(confirm_panel)
	UIScale.fit_panel(confirm_panel, get_viewport().get_visible_rect().size)
	confirm_accept_button.grab_focus()

func _on_settings_pressed() -> void:
	AudioManager.play("click", -8.0)
	refresh_settings_ui()
	show_panel(settings_panel)
	settings_back_button.grab_focus()

func _on_settings_back_pressed() -> void:
	AudioManager.play("click", -8.0)
	close_panels()

func refresh_settings_ui() -> void:
	volume_slider.set_value_no_signal(Records.settings_volume * 100.0)
	quality_low_button.text = ("▶ " + Loc.t("Низкое")) if Records.settings_quality == 0 else Loc.t("Низкое")
	quality_medium_button.text = ("▶ " + Loc.t("Среднее")) if Records.settings_quality == 1 else Loc.t("Среднее")
	quality_high_button.text = ("▶ " + Loc.t("Высокое")) if Records.settings_quality == 2 else Loc.t("Высокое")
	fps_check.set_pressed_no_signal(Records.settings_fps)
	shake_normal_button.text = ("▶ " + Loc.t("Обычная")) if Records.settings_shake == 0 else Loc.t("Обычная")
	shake_low_button.text = ("▶ " + Loc.t("Слабая")) if Records.settings_shake == 1 else Loc.t("Слабая")
	shake_off_button.text = ("▶ " + Loc.t("Выключить")) if Records.settings_shake == 2 else Loc.t("Выключить")
	ui_small_button.text = ("▶ " + Loc.t("Мелкий")) if Records.settings_ui_scale == 0 else Loc.t("Мелкий")
	ui_normal_button.text = ("▶ " + Loc.t("Обычный")) if Records.settings_ui_scale == 1 else Loc.t("Обычный")
	ui_large_button.text = ("▶ " + Loc.t("Крупный")) if Records.settings_ui_scale == 2 else Loc.t("Крупный")
	windowed_button.text = ("▶ " + Loc.t("Оконный")) if Records.settings_screen_mode == 0 else Loc.t("Оконный")
	fullscreen_button.text = ("▶ " + Loc.t("Во весь экран")) if Records.settings_screen_mode == 1 else Loc.t("Во весь экран")
	borderless_button.text = ("▶ " + Loc.t("Без рамки")) if Records.settings_screen_mode == 2 else Loc.t("Без рамки")
	lang_ru_button.text = ("▶ Русский") if Loc.locale == "ru" else "Русский"
	lang_en_button.text = ("▶ English") if Loc.locale == "en" else "English"

func _on_volume_changed(value: float) -> void:
	Records.set_volume(value / 100.0)

func _on_screen_mode_selected(mode_index: int) -> void:
	AudioManager.play("click", -8.0)
	Records.set_screen_mode(mode_index)
	refresh_settings_ui()

## Смена языка: сохраняем и перезагружаем меню, чтобы всё перерисовалось на новом языке.
func _on_language_selected(language_id: String) -> void:
	AudioManager.play("click", -8.0)
	Loc.set_locale(language_id)
	get_tree().reload_current_scene()

## Качество графики: низкое / среднее / высокое — бюджет частиц, цифры урона, яркость вспышек.
func _on_quality_selected(mode_index: int) -> void:
	AudioManager.play("click", -8.0)
	Records.set_quality(mode_index)
	refresh_settings_ui()

func _on_fps_toggled(enabled: bool) -> void:
	AudioManager.play("click", -10.0)
	Records.set_fps_counter(enabled)

## Тряска экрана: обычная / слабая / выключена (доступность — у некоторых она вызывает дискомфорт).
func _on_shake_selected(mode_index: int) -> void:
	AudioManager.play("click", -8.0)
	Records.set_shake(mode_index)
	refresh_settings_ui()

## Масштаб интерфейса: мелкий / обычный / крупный. Применяется сразу —
## шрифты и отступы пересчитываются, панель подгоняется под новый размер.
func _on_viewport_resized() -> void:
	for panel in all_panels:
		if panel.visible:
			UIScale.fit_panel(panel, get_viewport().get_visible_rect().size)

func _on_ui_scale_selected(mode_index: int) -> void:
	AudioManager.play("click", -8.0)
	Records.set_ui_scale(mode_index)
	UIScale.apply(self)
	refresh_settings_ui()
	UIScale.fit_panel(settings_panel, get_viewport().get_visible_rect().size)
	settings_back_button.grab_focus()

func build_character_list() -> void:
	for child in character_list.get_children():
		character_list.remove_child(child)
		child.queue_free()
	for char_data in Records.characters:
		var char_id: String = str(char_data["id"])
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_font_size_override("font_size", 13)
		var marker: String = "▶ " if char_id == Records.selected_character else ""
		button.text = "%s%s — %s\n%s" % [marker, Loc.t(str(char_data["name"])), Loc.t(str(char_data["spell_name"])), Loc.t(str(char_data["desc"]))]
		button.pressed.connect(_on_character_selected.bind(char_id))
		character_list.add_child(button)
	UIScale.apply(character_list)

func _on_character_selected(char_id: String) -> void:
	AudioManager.play("click", -8.0)
	Records.set_selected_character(char_id)
	build_character_list()

func _on_shop_pressed() -> void:
	AudioManager.play("click", -8.0)
	build_shop_list()
	show_panel(shop_panel)
	shop_back_button.grab_focus()

func _on_shop_back_pressed() -> void:
	AudioManager.play("click", -8.0)
	close_panels()

func build_shop_list() -> void:
	shop_gold_label.text = Loc.t("Золото: %d") % Records.gold
	for child in shop_list.get_children():
		shop_list.remove_child(child)
		child.queue_free()
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
