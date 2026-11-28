extends Node2D
## Ловушка арены. Два вида:
##   meteor — телеграф-круг, затем взрыв: большой урон всем в радиусе;
##   spikes — шипы: стоят пару секунд и периодически бьют всех, кто внутри.
## Урон получают ВСЕ: и игрок, и враги — на этом строится тактика карты.

var kind: String = "meteor"
var radius: float = 110.0
var player_damage: int = 25
var enemy_damage: int = 60
var telegraph_time: float = 0.9
var lifetime: float = 0.0
var tick_interval: float = 0.3

var state: String = "telegraph" # telegraph -> active -> fade
var timer: float = 0.0
var tick_timer: float = 0.0
var pulse: float = 0.0

@onready var fill: Polygon2D = $Fill
@onready var edge: Line2D = $Edge

func configure(trap_kind: String, trap_radius: float, damage_player: int, damage_enemy: int, delay: float) -> void:
	kind = trap_kind
	radius = trap_radius
	player_damage = damage_player
	enemy_damage = damage_enemy
	telegraph_time = delay
	if kind == "spikes":
		lifetime = 1.4
		tick_interval = 0.3
	else:
		lifetime = 0.0
		tick_interval = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 28
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	fill.polygon = points
	edge.points = points
	timer = telegraph_time
	_apply_visuals()

func _apply_visuals() -> void:
	# Цвета телеграфа — из Palette: с палитрой для дальтоников зона взрыва
	# становится маджентовой, шипы — фиолетовыми (обе видны на любом фоне).
	fill.color = Palette.hazard_fill(kind)
	edge.default_color = Palette.hazard_edge(kind)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	pulse += delta
	timer -= delta
	if state == "telegraph":
		# Чем ближе удар, тем ярче и «теснее» индикатор.
		var progress: float = 1.0 - clampf(timer / maxf(telegraph_time, 0.01), 0.0, 1.0)
		fill.color.a = 0.12 + progress * 0.35
		var squeeze: float = 1.25 - progress * 0.25
		fill.scale = Vector2(squeeze, squeeze)
		if timer <= 0.0:
			_trigger()
		return
	if state == "active":
		fill.color.a = 0.18 + absf(sin(pulse * 8.0)) * 0.22
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = tick_interval
			_damage_everyone(player_damage, enemy_damage, false)
		if timer <= 0.0:
			state = "fade"
			timer = 0.25
		return
	if state == "fade":
		modulate.a = clampf(timer / 0.25, 0.0, 1.0)
		if timer <= 0.0:
			queue_free()

func _trigger() -> void:
	if kind == "meteor":
		# Метеорит: разовый удар по площади + визуальный взрыв.
		AudioManager.play("explosion", -6.0)
		var impact_color: Color = Palette.danger_impact()
		FX.burst(global_position, impact_color, 26, 220.0)
		FX.shake(0.5, 4.0)
		var ring = load("res://scenes/nova_ring.tscn").instantiate()
		ring.configure(radius, global_position, impact_color)
		get_tree().current_scene.call_deferred("add_child", ring)
		_damage_everyone(player_damage, enemy_damage, true)
		queue_free()
	else:
		# Шипы: переходят в активную фазу и бьют по тикам.
		state = "active"
		timer = lifetime
		tick_timer = 0.0
		AudioManager.play("hit", -14.0, 0.6)

func _damage_everyone(damage_player: int, damage_enemy: int, impact: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) <= radius:
			player.call("take_damage", damage_player)
	for enemy in Enemies.all():
		if enemy.is_queued_for_deletion():
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.call("take_damage", damage_enemy, global_position, "traps")
	if impact:
		# Врагов, попавших под удар, слегка отбрасывает.
		for enemy in Enemies.all():
			if enemy.is_queued_for_deletion():
				continue
			var away: Vector2 = enemy.global_position - global_position
			if away.length() <= radius and away.length() > 1.0:
				enemy.set("knockback_velocity", Vector2(away.normalized()) * 190.0)
