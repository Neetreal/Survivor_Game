extends Area2D
## Копьё: пробивающий выстрел по прямой — проходит сквозь строй врагов
## и не останавливается на первом попадании.

var direction: Vector2 = Vector2.RIGHT
var damage: int = 26
var speed: float = 640.0
var max_range: float = 520.0
var traveled: float = 0.0
var pending_position: Vector2 = Vector2.ZERO
var hit_enemies: Array = []

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(angle: float, dmg: int, spd: float, range_limit: float, spawn_position: Vector2) -> void:
	direction = Vector2.from_angle(angle)
	damage = dmg
	speed = spd
	max_range = range_limit
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	FxVisual.use_sprite(body, visual, "fx_spear")
	FxVisual.add_trail(self, Color(0.8, 0.92, 1.0), 5.0, 0.16)
	FX.burst(global_position, Color(0.8, 0.92, 1.0), 3, 70.0)

func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	global_position += direction * step
	traveled += step
	if traveled >= max_range:
		queue_free()
		return
	# Ручная проверка перекрытий: сигнал может пропустить попадание на быстрой скорости.
	for area in get_overlapping_areas():
		_on_area_entered(area)

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	if hit_enemies.has(area):
		return
	hit_enemies.append(area)
	if area.has_method("take_damage"):
		area.call("take_damage", damage, global_position, "spear")
	FX.burst(area.global_position, Color(0.75, 0.9, 1.0), 5, 90.0)
