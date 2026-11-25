extends Area2D
## Снаряд врага (плевун): летит в игрока и наносит урон при касании.

var direction: Vector2 = Vector2.RIGHT
var damage: int = 10
var speed: float = 300.0
var life: float = 3.0
var pending_position: Vector2 = Vector2.ZERO

func configure(angle: float, dmg: int, spd: float, spawn_position: Vector2) -> void:
	direction = Vector2.from_angle(angle)
	damage = dmg
	speed = spd
	pending_position = spawn_position

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func _ready() -> void:
	FxVisual.use_sprite(body, visual, "fx_venom")
	FxVisual.add_glow(self, Color(0.45, 0.95, 0.4), 26.0, 0.5)
	FxVisual.add_trail(self, Color(0.45, 0.95, 0.4), 5.0, 0.16)
	FX.burst(global_position, Color(0.45, 0.95, 0.4), 3, 60.0)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if absf(global_position.x) > 1650.0 or absf(global_position.y) > 1650.0:
		queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", damage)
		FX.burst(global_position, Color(0.45, 0.95, 0.4), 5, 90.0)
		queue_free()
