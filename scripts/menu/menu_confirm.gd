class_name MenuConfirm
extends MenuPanel
## Окно подтверждения: сначала предупреждение о сбросе, затем итог операции.

# ── Узлы окна: заголовок, описание и ряд кнопок.
@onready var title_label: Label = $VBox/TitleLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var buttons_row: HBoxContainer = $VBox/Buttons
@onready var cancel_button: Button = $VBox/Buttons/CancelButton
@onready var accept_button: Button = $VBox/Buttons/AcceptButton

## Ширина текста при обычном масштабе. Нужна явно: у Label с переносом слов
## минимальная высота считается по текущей ширине, и при нулевой ширине
## окно раздувается на весь экран.
const DESC_WIDTH: float = 560.0
## Размеры окна: с предупреждением и с коротким итогом.
const WARN_SIZE: Vector2 = Vector2(620.0, 330.0)
const DONE_SIZE: Vector2 = Vector2(620.0, 226.0)

# ── Состояние окна: что сбрасываем и показан ли уже итог.
## Что подтверждаем: "records" (только рекорды) или "progress" (полный сброс).
var _kind: String = ""
## Окно уже показывает результат сброса — тогда кнопка называется «Ок».
var _done: bool = false

func _ready() -> void:
	cancel_button.pressed.connect(cancel)
	accept_button.pressed.connect(_on_accept_pressed)

# ── Фокус на «Отмене»: случайное нажатие A на геймпаде ничего не стирает.
func open() -> void:
	if _done:
		accept_button.grab_focus()
	else:
		cancel_button.grab_focus()

# ── Вопрос о сбросе. Ничего не меняем, пока не нажали «Сбросить».
func ask(kind: String) -> void:
	_kind = kind
	_done = false
	cancel_button.visible = true
	accept_button.text = Loc.t("Сбросить")
	desc_label.custom_minimum_size = Vector2(DESC_WIDTH * UIScale.factor(), 0.0)
	# Опасная кнопка занимает свою половину ряда, как и в других окнах.
	accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_button.custom_minimum_size.x = 0.0
	buttons_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	set_meta("ui_scale_base_size", WARN_SIZE)
	if kind == "records":
		title_label.text = Loc.t("Сбросить рекорды и историю?")
		desc_label.text = Loc.t("Пропадут:\n• лучшее время, убийства и уровень;\n• список последних забегов.\n\nЗолото, купленная прокачка, достижения и статистика профиля останутся.")
	else:
		title_label.text = Loc.t("Сбросить весь прогресс?")
		desc_label.text = Loc.t("Игра станет такой же, как при первом запуске.\n\nПропадут: золото, купленная прокачка, достижения, рекорды, история забегов и вся статистика профиля. Выбор героя, карты и сложности вернётся к стандартному.\n\nНастройки — звук, экран, язык, качество, масштаб — не изменятся.")
	menu.show_panel(self)

# ── «Отмена» (или Esc): возвращаемся в настройки, данные не тронуты.
func cancel() -> void:
	menu.show_panel(menu.settings_panel)
	if _done:
		menu.settings_panel.focus_back()
	else:
		menu.settings_panel.focus_danger(_kind)

func _on_accept_pressed() -> void:
	if _done:
		cancel()
		return
	if _kind == "records":
		Records.reset_records()
		AudioManager.play("gem", -8.0)
		menu.refresh_best_label()
		done(Loc.t("Рекорды сброшены"), Loc.t("Лучшее время, убийства, уровень и история забегов обнулены.\nЗолото, прокачка и достижения остались на месте."))
	else:
		Records.reset_progress()
		AudioManager.play("gem", -8.0)
		menu.refresh_best_label()
		done(Loc.t("Прогресс сброшен"), Loc.t("Золото, прокачка, достижения, рекорды и статистика обнулены — игра как при первом запуске.\nНастройки не изменились."))

# ── То же окно показывает итог: одна кнопка «Ок» и никакой опасной кнопки.
func done(title_text: String, text: String) -> void:
	_done = true
	desc_label.custom_minimum_size = Vector2(DESC_WIDTH * UIScale.factor(), 0.0)
	# В итоговом окне одна кнопка (узкая, по центру) и оно ниже — без пустоты.
	accept_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accept_button.custom_minimum_size.x = 220.0 * UIScale.factor()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	set_meta("ui_scale_base_size", DONE_SIZE)
	title_label.text = title_text
	desc_label.text = text
	cancel_button.visible = false
	accept_button.text = Loc.t("Ок")
	menu.show_panel(self)
