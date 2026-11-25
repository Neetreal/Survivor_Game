extends Area2D
## Мина: кладётся под ноги, взводится 0.5 с, взрывается при касании врага
## или через 12 секунд. Бьёт только врагов — игроку безопасна.

var damage: int = 40
var explosion_radius: float = 110.0
var armed: bool = false
var arm_timer: float = 0.5
var life: float = 12.0
var blink: float = 0.0
var exploded: bool = false

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(dmg: int, radius: float, spawn_position: Vector2) -> void:
	damage = dmg
	explosion_radius = radius
	position = spawn_position

func _ready() -> void:
	FxVisual.use_sprite(body, visual, "fx_mine")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if exploded:
		return
	if not armed:
		arm_timer -= delta
		FxVisual.set_color(body, visual, Color(0.9, 0.3, 0.25, 0.55))
		if arm_timer <= 0.0:
			armed = true
		return
	# Взведённая мина мигает и ждёт врага.
	blink += delta
	FxVisual.set_color(body, visual, Color(1.0, 0.25, 0.2, 0.7 + sin(blink * 9.0) * 0.3))
	life -= delta
	if life <= 0.0:
		explode()
		return
	for area in get_overlapping_areas():
		if area.is_in_group("enemies"):
			explode()
			return

func _on_area_entered(area) -> void:
	if armed and area.is_in_group("enemies"):
		explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	AudioManager.play("explosion", -6.0)
	FX.burst(global_position, Color(1.0, 0.45, 0.2), 22, 200.0)
	FX.shake(0.35, 4.0)
	var ring = load("res://scenes/nova_ring.tscn").instantiate()
	ring.configure(explosion_radius, global_position, Color(1.0, 0.45, 0.15))
	get_tree().current_scene.call_deferred("add_child", ring)
	var player = get_tree().get_first_node_in_group("player")
	var total_damage: int = damage
	for enemy in Enemies.all():
		if enemy.is_queued_for_deletion():
			continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.call("take_damage", total_damage, global_position, "mine")
	if player != null:
		pass # Мина игроку не вредит
	queue_free()
