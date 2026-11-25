extends Area2D
## Пила: летит по большой окружности вокруг точки броска, вращаясь,
## и режет всех, кого задевает. Не следует за игроком — её надо «заслужить» позицией.

var damage: int = 12
var orbit_radius: float = 190.0
var max_radius: float = 190.0
var angular_speed: float = 5.2
var center: Vector2 = Vector2.ZERO
var angle: float = 0.0
var life: float = 4.0
var hit_timer: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(dmg: int, orbit_r: float, spawn_center: Vector2) -> void:
	damage = dmg
	orbit_radius = orbit_r
	max_radius = orbit_r
	center = spawn_center

func _ready() -> void:
	FxVisual.use_sprite(body, visual, "fx_saw")
	FxVisual.add_trail(self, Color(0.85, 0.92, 1.0), 6.0, 0.18)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	angle = randf() * TAU
	# Пила раскручивается: начинается с малого радиуса и уезжает наружу.
	orbit_radius *= 0.35
	global_position = center + Vector2(cos(angle), sin(angle)) * orbit_radius

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	angle += angular_speed * delta
	orbit_radius = minf(orbit_radius + 150.0 * delta, max_radius)
	var target: Vector2 = center + Vector2(cos(angle), sin(angle)) * orbit_radius
	global_position = target
	visual.rotation += 18.0 * delta
	body.rotation += 18.0 * delta
	if hit_timer > 0.0:
		hit_timer -= delta
		return
	for area in get_overlapping_areas():
		if area.is_in_group("enemies"):
			area.call("take_damage", damage, global_position, "saw")
			hit_timer = 0.12
			FX.burst(global_position, Color(0.85, 0.9, 0.95), 4, 80.0)
			return
