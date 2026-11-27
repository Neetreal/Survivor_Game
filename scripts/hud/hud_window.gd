class_name HudWindow
extends PanelContainer
## Базовое окно HUD: ссылка на диспетчер и общие помощники.

## Диспетчер HUD (hud.gd): окна не знают друг о друге, только о нём.
var hud

## Щелчок по кнопке окна — один и тот же звук во всех окнах.
func click() -> void:
	AudioManager.play("click", -8.0)

## Подогнать окно под содержимое и текущий масштаб интерфейса.
func fit() -> void:
	UIScale.fit_panel(self, get_viewport().get_visible_rect().size)
