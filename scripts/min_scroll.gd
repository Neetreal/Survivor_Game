class_name MinScroll
extends ScrollContainer
## Скролл с честным минимальным размером.
##
## У обычного ScrollContainer минимальный размер равен размеру содержимого:
## длинный список распирает панель, и она вылезает за экран вместо того,
## чтобы прокручиваться. Здесь минимум берётся только из custom_minimum_size,
## поэтому UIScale.fit_panel может отдать скроллу ровно столько высоты,
## сколько осталось на экране.

func _get_minimum_size() -> Vector2:
	return custom_minimum_size
