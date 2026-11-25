extends Node2D
## Ядовитое облако: стоит на месте 4 секунды и каждые 0.5 с травит врагов внутри.
## Игроку не вредит — это его оружие.

var damage: int = 5
var radius: float = 115.0
var duration: float = 4.0
var tick_interval: float = 0.5
var tick_timer: float = 0.0
var life: float = 4.0
var pulse: float = 0.0

@onready var visual: Polygon2D = $Visual

func configure(dmg: int, cloud_radius: float, cloud_duration: float, spawn_position: Vector2) -> void:
	damage = dmg
	radius = cloud_radius
	duration = cloud_duration
	position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 30
	for i in range(segments):
		# Неровный край — облако, а не ровный круг.
		var angle: float = TAU * float(i) / float(segments)
		var wobble: float = 1.0 + sin(angle * 3.0 + randf() * 0.4) * 0.08
		points.append(Vector2(cos(angle), sin(angle)) * radius * wobble)
	visual.polygon = points
	FxVisual.add_glow(self, Color(0.4, 0.9, 0.3), radius * 1.7, 0.35)
	life = duration

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	pulse += delta
	life -= delta
	visual.color = Color(0.4, 0.9, 0.35, 0.22 + sin(pulse * 3.0) * 0.06)
	visual.rotation = sin(pulse * 0.8) * 0.15
	if life <= 0.0:
		queue_free()
		return
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		for enemy in Enemies.all():
			if enemy.is_queued_for_deletion():
				continue
			if global_position.distance_to(enemy.global_position) <= radius:
				enemy.call("take_damage", damage, global_position, "poison")
		FX.burst(global_position + Vector2(randf_range(-radius * 0.6, radius * 0.6), randf_range(-radius * 0.6, radius * 0.6)), Color(0.45, 0.95, 0.4), 3, 40.0)
