extends Area2D
## Магический снаряд: летит прямо, бьёт врагов.

var direction: Vector2 = Vector2.RIGHT
var damage: int = 10
var speed: float = 540.0
var pierce: int = 1
var life: float = 1.4
var max_range: float = 420.0 # Снаряд исчезает, пролетев это расстояние
var traveled: float = 0.0
var pending_position: Vector2 = Vector2.ZERO
var hit_enemies: Array = []
## Сколько ещё раз снаряд отскочит в следующего врага («Рикошет»).
var ricochets: int = 0
## Скорость доворота на цель в радианах за секунду (0 — летит прямо, «Кара»).
var homing_speed: float = 0.0
## Урон каждого следующего отскока (70% от предыдущего попадания).
const BOUNCE_FALLOFF: float = 0.7
## Радиус поиска следующей цели для отскока и для доворота.
const RETARGET_RADIUS: float = 260.0
## Спрайт и цвет эффектов задаются при выстреле: у стрел лучника своя картинка,
## у вражеских «плевков» остаётся прежний магический шар.
var sprite_name: String = "fx_bolt"
var effect_color: Color = Color(0.5, 0.8, 1.0)

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(angle: float, dmg: int, spd: float, pierce_count: int, spawn_position: Vector2,
		range_limit: float = 420.0, ricochet_count: int = 0, homing: float = 0.0,
		visual_sprite: String = "fx_bolt", visual_color: Color = Color(0.5, 0.8, 1.0)) -> void:
	direction = Vector2.from_angle(angle)
	damage = dmg
	speed = spd
	pierce = pierce_count
	ricochets = ricochet_count
	homing_speed = homing
	pending_position = spawn_position
	max_range = range_limit
	sprite_name = visual_sprite
	effect_color = visual_color
	if spd > 0.0:
		life = range_limit / spd

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	# Спрайт + свечение + след: снаряд читается как «магия», а не как ромбик.
	FxVisual.use_sprite(body, visual, sprite_name)
	FxVisual.add_glow(self, effect_color, 34.0, 0.5)
	FxVisual.add_trail(self, effect_color.lightened(0.15), 7.0, 0.2)
	# Вспышка у руки стрелка: снаряд «выходит» с эффектом, а не появляется из ничего.
	FX.burst(global_position, effect_color.lightened(0.2), 4, 70.0)

## Ближайший живой враг, в которого снаряд ещё не попадал.
func _find_next_target(from_position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist: float = RETARGET_RADIUS
	for enemy in Enemies.all():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion() or bool(enemy.get("dead")):
			continue
		if hit_enemies.has(enemy):
			continue
		var dist: float = from_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

## Самонаведение: плавно доворачиваем снаряд, а не телепортируем направление.
func _apply_homing(delta: float) -> void:
	if homing_speed <= 0.0:
		return
	var target: Node2D = _find_next_target(global_position)
	if target == null:
		return
	var wanted: float = (target.global_position - global_position).angle()
	var current: float = direction.angle()
	var diff: float = wrapf(wanted - current, -PI, PI)
	var max_step: float = homing_speed * delta
	direction = Vector2.from_angle(current + clampf(diff, -max_step, max_step))
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	_apply_homing(delta)
	var step: float = speed * delta
	global_position += direction * step
	traveled += step
	life -= delta
	# Лимит дальности: снаряд не летит через всю карту.
	if traveled >= max_range or life <= 0.0:
		queue_free()
		return
	if absf(global_position.x) > 1650.0 or absf(global_position.y) > 1650.0:
		queue_free()
		return
	# Страховка: проверяем пересечения вручную каждый кадр.
	# Сигнал area_entered может пропустить попадание, когда несколько
	# снарядов стартуют рядом и прилетают в врага одновременно.
	for area in get_overlapping_areas():
		_on_area_entered(area)
		if is_queued_for_deletion():
			break

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	if hit_enemies.has(area):
		return
	hit_enemies.append(area)
	if area.has_method("take_damage"):
		area.call("take_damage", damage, global_position, "bolt")
	# Искры в точке попадания.
	FX.burst(area.global_position, Color(0.65, 0.85, 1.0), 4, 90.0)
	# Рикошет: снаряд не гаснет, а скачет в следующего врага с ослабленным уроном.
	if ricochets > 0:
		var next_target: Node2D = _find_next_target(area.global_position)
		if next_target != null:
			ricochets -= 1
			damage = maxi(1, int(round(float(damage) * BOUNCE_FALLOFF)))
			direction = (next_target.global_position - global_position).normalized()
			rotation = direction.angle()
			# Отскок получает свой запас дальности, иначе снаряд гас бы сразу.
			traveled = 0.0
			life = max_range / maxf(1.0, speed)
			FX.burst(global_position, Color(0.75, 0.9, 1.0), 5, 110.0)
			return
	pierce -= 1
	if pierce <= 0:
		queue_free()
