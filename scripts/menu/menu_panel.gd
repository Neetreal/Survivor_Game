class_name MenuPanel
extends PanelContainer
## Базовое окно главного меню: ссылка на диспетчер и общие помощники для кнопок.

## Диспетчер меню (main_menu.gd): окна не знают друг о друге напрямую.
var menu

## Вызывается при показе окна: наполнить данными и отдать фокус первой кнопке.
func open() -> void:
	pass

## Щелчок по кнопке меню — один и тот же звук во всех окнах.
func click(volume_db: float = -8.0) -> void:
	AudioManager.play("click", volume_db)

## Кнопка «Назад»: закрыть окно и вернуть фокус в главное меню.
func back() -> void:
	click()
	menu.close_panels()

## Подпись кнопки-варианта: маркер ▶ у выбранного значения.
func choice(button: Button, text: String, selected: bool) -> void:
	button.text = ("▶ " + text) if selected else text

## Очистить список перед перестройкой: строки убираем сразу, чтобы не дублировались.
func clear_list(list: Node) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
