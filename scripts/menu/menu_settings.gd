class_name MenuSettings
extends MenuPanel
## Настройки: звук, экран, качество, FPS, тряска, масштаб интерфейса, язык и сброс.

# ── Узлы окна: громкость, режим экрана, тряска, язык, качество, FPS, масштаб, сброс.
@onready var volume_slider: HSlider = $VBox/Columns/Left/VolumeSlider
@onready var windowed_button: Button = $VBox/Columns/Left/ScreenBox/WindowedButton
@onready var fullscreen_button: Button = $VBox/Columns/Left/ScreenBox/FullscreenButton
@onready var borderless_button: Button = $VBox/Columns/Left/ScreenBox/BorderlessButton
@onready var shake_normal_button: Button = $VBox/Columns/Left/ShakeBox/ShakeNormalButton
@onready var shake_low_button: Button = $VBox/Columns/Left/ShakeBox/ShakeLowButton
@onready var shake_off_button: Button = $VBox/Columns/Left/ShakeBox/ShakeOffButton
@onready var quality_low_button: Button = $VBox/Columns/Right/QualityBox/LowButton
@onready var quality_medium_button: Button = $VBox/Columns/Right/QualityBox/MediumButton
@onready var quality_high_button: Button = $VBox/Columns/Right/QualityBox/HighButton
@onready var fps_check: CheckButton = $VBox/Columns/Right/FpsCheck
@onready var lang_ru_button: Button = $VBox/Columns/Right/LanguageBox/RuButton
@onready var lang_en_button: Button = $VBox/Columns/Right/LanguageBox/EnButton
@onready var ui_small_button: Button = $VBox/Columns/Right/UIScaleBox/SmallButton
@onready var ui_normal_button: Button = $VBox/Columns/Right/UIScaleBox/NormalButton
@onready var ui_large_button: Button = $VBox/Columns/Right/UIScaleBox/LargeButton
@onready var reset_records_button: Button = $VBox/DangerBox/ResetRecordsButton
@onready var reset_progress_button: Button = $VBox/DangerBox/ResetProgressButton
@onready var back_button: Button = $VBox/BackButton

# ── Подписка на все переключатели окна.
func _ready() -> void:
	back_button.pressed.connect(back)
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
	reset_records_button.pressed.connect(_on_reset_records_pressed)
	reset_progress_button.pressed.connect(_on_reset_progress_pressed)

func open() -> void:
	refresh()
	back_button.grab_focus()

# ── Возврат из окна подтверждения: фокус на «Назад» или на кнопке сброса.
func focus_back() -> void:
	back_button.grab_focus()

func focus_danger(kind: String) -> void:
	if kind == "records":
		reset_records_button.grab_focus()
	else:
		reset_progress_button.grab_focus()

# ── Отрисовка настроек: выделение текущих значений маркером ▶ без вызова сигналов.
func refresh() -> void:
	volume_slider.set_value_no_signal(Records.settings_volume * 100.0)
	choice(quality_low_button, Loc.t("Низкое"), Records.settings_quality == 0)
	choice(quality_medium_button, Loc.t("Среднее"), Records.settings_quality == 1)
	choice(quality_high_button, Loc.t("Высокое"), Records.settings_quality == 2)
	fps_check.set_pressed_no_signal(Records.settings_fps)
	choice(shake_normal_button, Loc.t("Обычная"), Records.settings_shake == 0)
	choice(shake_low_button, Loc.t("Слабая"), Records.settings_shake == 1)
	choice(shake_off_button, Loc.t("Выключить"), Records.settings_shake == 2)
	choice(ui_small_button, Loc.t("Мелкий"), Records.settings_ui_scale == 0)
	choice(ui_normal_button, Loc.t("Обычный"), Records.settings_ui_scale == 1)
	choice(ui_large_button, Loc.t("Крупный"), Records.settings_ui_scale == 2)
	choice(windowed_button, Loc.t("Оконный"), Records.settings_screen_mode == 0)
	choice(fullscreen_button, Loc.t("Во весь экран"), Records.settings_screen_mode == 1)
	choice(borderless_button, Loc.t("Без рамки"), Records.settings_screen_mode == 2)
	choice(lang_ru_button, "Русский", Loc.locale == "ru")
	choice(lang_en_button, "English", Loc.locale == "en")

# ── Обработчики настроек: громкость, экран, язык, качество, FPS, тряска, масштаб.
func _on_volume_changed(value: float) -> void:
	Records.set_volume(value / 100.0)

func _on_screen_mode_selected(mode_index: int) -> void:
	click()
	Records.set_screen_mode(mode_index)
	refresh()

## Смена языка: сохраняем и перезагружаем меню, чтобы всё перерисовалось на новом языке.
func _on_language_selected(language_id: String) -> void:
	click()
	Loc.set_locale(language_id)
	get_tree().reload_current_scene()

## Качество графики: низкое / среднее / высокое — бюджет частиц, цифры урона, яркость вспышек.
func _on_quality_selected(mode_index: int) -> void:
	click()
	Records.set_quality(mode_index)
	refresh()

func _on_fps_toggled(enabled: bool) -> void:
	click(-10.0)
	Records.set_fps_counter(enabled)

## Тряска экрана: обычная / слабая / выключена (доступность — у некоторых она вызывает дискомфорт).
func _on_shake_selected(mode_index: int) -> void:
	click()
	Records.set_shake(mode_index)
	refresh()

## Масштаб интерфейса: мелкий / обычный / крупный. Применяется сразу —
## шрифты и отступы пересчитываются, панель подгоняется под новый размер.
func _on_ui_scale_selected(mode_index: int) -> void:
	click()
	Records.set_ui_scale(mode_index)
	UIScale.apply(menu as Node)
	refresh()
	UIScale.fit_panel(self, get_viewport().get_visible_rect().size)
	back_button.grab_focus()

# ── Сброс данных: сначала окно подтверждения — ничего не стирается сразу.
func _on_reset_records_pressed() -> void:
	click()
	menu.confirm_panel.ask("records")

func _on_reset_progress_pressed() -> void:
	click()
	menu.confirm_panel.ask("progress")
