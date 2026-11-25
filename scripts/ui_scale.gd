class_name UIScale
extends RefCounted
## Масштаб интерфейса: Мелкий (90%) / Обычный (100%) / Крупный (120%).
##
## Почему не через Window.content_scale_factor: он увеличивает ВСЁ содержимое,
## включая мир — игрок увидел бы больше или меньше поля боя, а это меняет баланс
## и ощущение игры. Поэтому масштабируем только интерфейс:
##   1. размеры шрифтов у всех Control в дереве (базовый размер запоминается в meta,
##      чтобы повторное применение не накапливалось);
##   2. внутренние отступы и скругления общей темы (ui_theme.tres);
##   3. сами панели — по их минимальному размеру, с центрированием и подгонкой
##      под экран (если содержимое выше экрана, «съедаем» высоту у внутреннего скролла).
##
## Позиции элементов HUD заданы якорями, поэтому подписи при увеличении растут
## в сторону своего края экрана, а не наезжают на соседей.

const FACTORS: Array[float] = [0.9, 1.0, 1.2]
const LABEL_KEYS: Array[String] = ["Мелкий", "Обычный", "Крупный"]
const THEME: Theme = preload("res://scenes/ui_theme.tres")
const SCREEN_MARGIN: float = 24.0 # Минимальный отступ панели от края экрана
const MIN_SCROLL_HEIGHT: float = 120.0 # Ниже этого внутренний скролл не сжимаем

## Текущий множитель из настроек (Records.settings_ui_scale: 0 / 1 / 2).
static func factor() -> float:
	return FACTORS[clampi(Records.settings_ui_scale, 0, FACTORS.size() - 1)]

## Ключ локализации для подписи кнопки с этим индексом.
static func label_key(index: int) -> String:
	return LABEL_KEYS[clampi(index, 0, LABEL_KEYS.size() - 1)]

## Размер шрифта с учётом масштаба — для мест, где размер задаётся кодом.
static func font(size: int) -> int:
	return maxi(8, int(round(float(size) * factor())))

## Применить масштаб ко всему интерфейсу под root.
static func apply(root: Node) -> void:
	var f: float = factor()
	_scale_fonts(root, f)
	_scale_theme(f)

## Панель — по её дизайнерскому размеру (в масштабе), но не больше содержимого
## и не больше экрана. Если содержимое выше экрана, «съедаем» высоту у скролла.
## Вызывается при открытии панели, когда содержимое уже собрано.
## Два прохода подряд: после первой подгонки минимальные размеры дочерних
## контейнеров пересчитываются только к концу кадра, поэтому панель с длинным
## списком выше экрана ужимается лишь на втором проходе (видно на Крупном масштабе).
## update_minimum_size() заставляет контейнеры пересчитать минимум сразу.
static func fit_panel(panel: Control, viewport_size: Vector2) -> void:
	if panel == null:
		return
	_fit_pass(panel, viewport_size)
	panel.update_minimum_size()
	_fit_pass(panel, viewport_size)

static func _fit_pass(panel: Control, viewport_size: Vector2) -> void:
	var f: float = factor()
	var avail: Vector2 = viewport_size - Vector2(SCREEN_MARGIN * 2.0, SCREEN_MARGIN * 2.0)
	var scroll: ScrollContainer = _find_scroll(panel)
	# Базовые (дизайнерские) размеры приходят из сцены и умножаются на масштаб.
	panel.custom_minimum_size = _base_size(panel) * f
	if scroll != null:
		scroll.custom_minimum_size = _base_size(scroll) * f
	var content: Vector2 = panel.get_combined_minimum_size()
	# Не влезает по высоте — отдаём «лишнее» внутреннему скроллу.
	if content.y > avail.y and scroll != null:
		scroll.custom_minimum_size.y = maxf(MIN_SCROLL_HEIGHT, scroll.custom_minimum_size.y - (content.y - avail.y))
		content = panel.get_combined_minimum_size()
	# Всё равно не влезает — урезаем саму панель (остальное решает скролл/обрезка).
	if content.y > avail.y:
		panel.custom_minimum_size.y = maxf(0.0, panel.custom_minimum_size.y - (content.y - avail.y))
		content = panel.get_combined_minimum_size()
	var target: Vector2 = Vector2(minf(content.x, avail.x), minf(content.y, avail.y))
	panel.size = target
	panel.position = ((viewport_size - target) * 0.5).round()

## Дизайнерский размер узла (запоминается при первом обращении из сцены).
static func _base_size(node: Control) -> Vector2:
	if not node.has_meta("ui_scale_base_size"):
		node.set_meta("ui_scale_base_size", node.custom_minimum_size)
	return node.get_meta("ui_scale_base_size")

## Подогнать сразу список панелей (удобно вызывать на смене размера окна).
static func fit_panels(panels: Array, viewport_size: Vector2) -> void:
	for panel in panels:
		if panel is Control and panel.visible:
			fit_panel(panel, viewport_size)


### Внутреннее ###

static func _scale_fonts(root: Node, f: float) -> void:
	var controls: Array = []
	if root is Control:
		controls.append(root)
	controls.append_array(root.find_children("*", "Control", true, false))
	for node in controls:
		var control: Control = node
		if not control.has_meta("ui_scale_base_font"):
			control.set_meta("ui_scale_base_font", int(control.get_theme_font_size("font_size")))
		var base: int = int(control.get_meta("ui_scale_base_font"))
		control.add_theme_font_size_override("font_size", maxi(8, int(round(float(base) * f))))
		# Кнопкам увеличиваем и высоту, иначе текст в них становится тесным.
		if control is BaseButton:
			if not control.has_meta("ui_scale_base_min"):
				control.set_meta("ui_scale_base_min", control.custom_minimum_size)
			var button_min: Vector2 = control.get_meta("ui_scale_base_min")
			control.custom_minimum_size = Vector2(button_min.x, button_min.y * f)

static func _scale_theme(f: float) -> void:
	for type_name in ["PanelContainer", "Panel"]:
		var box: StyleBox = THEME.get_stylebox("panel", type_name)
		if not (box is StyleBoxFlat):
			continue
		var flat: StyleBoxFlat = box
		if not flat.has_meta("ui_scale_base"):
			flat.set_meta("ui_scale_base", [
				flat.content_margin_left, flat.content_margin_top,
				flat.content_margin_right, flat.content_margin_bottom,
				float(flat.corner_radius_top_left), float(flat.border_width_left),
			])
		var base: Array = flat.get_meta("ui_scale_base")
		flat.content_margin_left = float(base[0]) * f
		flat.content_margin_top = float(base[1]) * f
		flat.content_margin_right = float(base[2]) * f
		flat.content_margin_bottom = float(base[3]) * f
		var radius: int = int(round(float(base[4]) * f))
		flat.corner_radius_top_left = radius
		flat.corner_radius_top_right = radius
		flat.corner_radius_bottom_left = radius
		flat.corner_radius_bottom_right = radius
		flat.border_width_left = int(round(float(base[5]) * f))
		flat.border_width_top = int(round(float(base[5]) * f))
		flat.border_width_right = int(round(float(base[5]) * f))
		flat.border_width_bottom = int(round(float(base[5]) * f))

## Первый вертикальный скролл внутри панели — его высоту можно отдать экрану.
static func _find_scroll(root: Node) -> ScrollContainer:
	for node in root.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = node
		if scroll.get_parent() is VBoxContainer:
			return scroll
	return null
