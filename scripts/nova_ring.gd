extends Node2D
## Кольцо новы: чисто визуальный расширяющийся круг.
## Урон в момент импульса наносит игрок (trigger_nova в player_weapons.gd),
## а кольцо только показывает, как ударная волна разошлась по площади.

var max_radius: float = 140.0
var ring_color: Color = Color(0.4, 0.85, 1.0)
var duration: float = 0.35
var age: float = 0.0
var pending_position: Vector2 = Vector2.ZERO

@onready var visual: Polygon2D = $Visual
var glow: Sprite2D = null

func configure(radius: float, spawn_position: Vector2, color: Color = Color(0.4, 0.85, 1.0)) -> void:
	max_radius = radius
	pending_position = spawn_position
	ring_color = color

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	visual.color = ring_color
	z_index = 5
	glow = FxVisual.add_glow(self, ring_color, max_radius * 1.6, 0.3)

func _process(delta: float) -> void:
	age += delta
	var t: float = clampf(age / duration, 0.0, 1.0)
	var current_radius: float = maxf(1.0, max_radius * t)
	visual.scale = Vector2(current_radius, current_radius) # Полигон — круг радиуса 1
	visual.modulate.a = 0.45 * (1.0 - t)
	if glow != null:
		glow.scale = Vector2.ONE * (max_radius * 1.6 * maxf(0.2, t) / 128.0)
		glow.modulate.a = 0.35 * (1.0 - t)
	if age >= duration:
		queue_free()
