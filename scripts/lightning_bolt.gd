extends Node2D
## Молния: рисует зигзаг между точками цепи и быстро гаснет.
## Чисто визуальный эффект — урон наносит игрок в trigger_chain (player.gd).

var pending_points: Array = []
var life: float = 0.18
var age: float = 0.0

func configure(points: Array) -> void:
	pending_points = points

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 6
	for i in range(pending_points.size() - 1):
		var a: Vector2 = pending_points[i]
		var b: Vector2 = pending_points[i + 1]
		var mid: Vector2 = (a + b) * 0.5
		var dir: Vector2 = (b - a).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		mid += perp * randf_range(-14.0, 14.0) # Ломаная линия, как у настоящей молнии
		var pts: PackedVector2Array = PackedVector2Array([a, mid, b])
		var glow: Line2D = Line2D.new()
		glow.width = 7.0
		glow.default_color = Color(0.5, 0.75, 1.0, 0.35)
		glow.points = pts
		add_child(glow)
		var core: Line2D = Line2D.new()
		core.width = 2.5
		core.default_color = Color(0.85, 0.95, 1.0, 1.0)
		core.points = pts
		add_child(core)

func _process(delta: float) -> void:
	age += delta
	modulate.a = clampf(1.0 - age / life, 0.0, 1.0)
	if age >= life:
		queue_free()
