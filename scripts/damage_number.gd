extends Label
## Всплывающая цифра урона.

var pending_text: String = "0"
var pending_position: Vector2 = Vector2.ZERO
var pending_heal: bool = false
var life: float = 0.6

func configure(value: int, spawn_position: Vector2) -> void:
	pending_text = str(value)
	pending_position = spawn_position

## Цифра лечения «+12»: зелёная, с палитрой для дальтоников — голубая.
## Знак «+» остаётся главной подсказкой, цвет — второй.
func configure_heal(value: int, spawn_position: Vector2) -> void:
	pending_text = "+%d" % value
	pending_heal = true
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	text = pending_text
	global_position = pending_position
	add_theme_font_size_override("font_size", UIScale.font(16))
	# Цвет берём из палитры в момент показа: настройка «для дальтоников» успевает примениться.
	add_theme_color_override("font_color", Palette.heal() if pending_heal else Palette.damage_text())
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	add_theme_constant_override("outline_size", 4)

func _process(delta: float) -> void:
	life -= delta
	position.y -= 42.0 * delta
	modulate.a = clampf(life / 0.6, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
