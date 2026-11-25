extends Label
## Всплывающая цифра урона.

var pending_text: String = "0"
var pending_position: Vector2 = Vector2.ZERO
var pending_color: Color = Color(1.0, 0.9, 0.35)
var life: float = 0.6

func configure(value: int, spawn_position: Vector2) -> void:
	pending_text = str(value)
	pending_position = spawn_position

## Зелёная цифра лечения: «+12».
func configure_heal(value: int, spawn_position: Vector2) -> void:
	pending_text = "+%d" % value
	pending_color = Color(0.45, 1.0, 0.5)
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	text = pending_text
	global_position = pending_position
	add_theme_font_size_override("font_size", UIScale.font(16))
	add_theme_color_override("font_color", pending_color)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	add_theme_constant_override("outline_size", 4)

func _process(delta: float) -> void:
	life -= delta
	position.y -= 42.0 * delta
	modulate.a = clampf(life / 0.6, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
