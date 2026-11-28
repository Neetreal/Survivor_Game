extends Area2D
## Зона трясины: замедляет всех, кто внутри — и игрока, и врагов.
## Используется на карте «Топкие болота».

var slow_factor: float = 0.55 # Множитель скорости внутри зоны (0.55 = на 45% медленнее)
var radius: float = 150.0
var zone_color: Color = Color(0.16, 0.30, 0.20, 0.55) # обычная палитра; см. _ready()
var pulse_phase: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var edge: Line2D = $Edge
@onready var shape_node: CollisionShape2D = $CollisionShape2D

func configure(zone_radius: float, factor: float) -> void:
	radius = zone_radius
	slow_factor = factor

func _ready() -> void:
	# Как и остальные игровые объекты — встаёт на паузу при выборе улучшения.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Круг рисуем кодом, чтобы радиус всегда совпадал с зоной замедления.
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 32
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = points
	zone_color = Palette.slow_zone()
	visual.color = zone_color
	edge.points = points
	edge.default_color = Color(zone_color.r + 0.18, zone_color.g + 0.22, zone_color.b + 0.14, 0.5)
	# Форма своя у каждой зоны (ресурс в сцене общий, его нужно продублировать).
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	pulse_phase = randf() * TAU

func _process(delta: float) -> void:
	# Лёгкое «дыхание» трясины, чтобы зона читалась на фоне.
	if get_tree().paused:
		return
	pulse_phase += delta
	var breath: float = 1.0 + sin(pulse_phase * 1.8) * 0.03
	visual.scale = Vector2(breath, breath)
	visual.modulate = Color(1.0, 1.0, 1.0, 1.0 + sin(pulse_phase * 1.4) * 0.18)

func _physics_process(_delta: float) -> void:
	# Игрок — CharacterBody2D (тело).
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("apply_zone_slow"):
			body.call("apply_zone_slow", slow_factor)
	# Враги — Area2D, у них уже есть механика замедления от «Мороза».
	for area in get_overlapping_areas():
		if not area.is_in_group("enemies"):
			continue
		var current_timer: float = float(area.get("slow_timer"))
		if current_timer <= 0.0:
			area.set("slow_factor", slow_factor)
		else:
			# Если враг уже заморожен сильнее — не ослабляем эффект.
			area.set("slow_factor", minf(float(area.get("slow_factor")), slow_factor))
		area.set("slow_timer", maxf(current_timer, 0.15))
