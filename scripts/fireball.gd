extends Area2D
## Огненный шар: летит до первого врага и взрывается по площади.

const NovaRingScene: PackedScene = preload("res://scenes/nova_ring.tscn")

var direction: Vector2 = Vector2.RIGHT
var damage: int = 20
var speed: float = 460.0
var explosion_radius: float = 75.0
var max_range: float = 380.0
var traveled: float = 0.0
var pending_position: Vector2 = Vector2.ZERO
var exploded: bool = false

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(angle: float, dmg: int, spd: float, explosion_rad: float, spawn_position: Vector2) -> void:
	direction = Vector2.from_angle(angle)
	damage = dmg
	speed = spd
	explosion_radius = explosion_rad
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	FxVisual.use_sprite(body, visual, "fx_fireball")
	FxVisual.add_glow(self, Color(1.0, 0.55, 0.2), 46.0, 0.6)
	FxVisual.add_trail(self, Color(1.0, 0.5, 0.2), 9.0, 0.26)
	FX.burst(global_position, Color(1.0, 0.6, 0.25), 5, 80.0)

func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	global_position += direction * step
	traveled += step
	if traveled >= max_range:
		queue_free()
		return
	for area in get_overlapping_areas():
		_on_area_entered(area)
		if exploded:
			break

func _on_area_entered(area) -> void:
	if area.is_in_group("enemies"):
		explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	AudioManager.play("explosion", -4.0)
	FX.burst(global_position, Color(1.0, 0.55, 0.25), 20, 180.0)
	FX.shake(0.55, 4.5)
	for enemy in Enemies.all():
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.call("take_damage", damage, global_position, "fireball")
	var ring = NovaRingScene.instantiate()
	ring.configure(explosion_radius, global_position, Color(1.0, 0.55, 0.25))
	get_tree().current_scene.call_deferred("add_child", ring)
	queue_free()
