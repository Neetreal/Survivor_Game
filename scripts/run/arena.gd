class_name RunArena
extends Node
## Карта и её объекты: оформление арены, зоны трясины, ловушки и метеоритный дождь.

# ── Ссылка на забег (main.gd): через неё берём игрока, HUD и лимит врагов.
var m

# ── Состояние карты: ловушки, их таймеры, бонус золота и зоны трясины.
var map_traps: bool = false
var trap_timer: float = 6.5
var shower_timer: float = 40.0
var map_gold_bonus: float = 1.0
var slow_zones: Array = [] # Зоны трясины на текущей карте

# ── Сцены карты: зона трясины и ловушка — preload один раз на старте.
const SlowZoneScene: PackedScene = preload("res://scenes/slow_zone.tscn")
const HazardScene: PackedScene = preload("res://scenes/hazard.tscn")

# ── Кадр карты: ловушки арены — обычные каждые 6.5 с, метеоритный дождь раз в 40 с.
func tick(delta: float) -> void:
	if not map_traps:
		return
	trap_timer -= delta
	if trap_timer <= 0.0:
		spawn_hazard()
		trap_timer = 6.5
	shower_timer -= delta
	if shower_timer <= 0.0:
		spawn_meteor_shower()
		shower_timer = 40.0

# ── Карта: цвет фона и декора, ловушки, бонус золота, зоны трясины.
func apply_map() -> void:
	# Оформление арены под выбранную карту + её особые объекты.
	var map_data: Dictionary = Records.get_map()
	var background: Polygon2D = m.get_node_or_null("Background")
	if background != null:
		background.color = map_data["background"]
	for i in range(1, 6):
		var decor = m.get_node_or_null("Decor%d" % i)
		if decor != null:
			decor.color = map_data["decor"]
	map_traps = bool(map_data.get("traps", false))
	map_gold_bonus = float(map_data.get("gold_bonus", 1.0))
	m.max_enemies += int(map_data.get("enemy_cap_bonus", 0))
	var zone_count: int = int(map_data.get("slow_zones", 0))
	if zone_count > 0:
		spawn_slow_zones(zone_count)
		m.hud.announce(Loc.t(str(map_data["name"])).to_upper() + "!", Color(0.6, 0.95, 0.6), 30)
	elif map_traps:
		m.hud.announce(Loc.t(str(map_data["name"])).to_upper() + "!", Color(1.0, 0.6, 0.4), 30)

# ── Зоны трясины: раскладка фиксированным сидом, чтобы карта была одинаковой в каждом забеге.
func spawn_slow_zones(count: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261114
	var placed: Array = []
	var attempts: int = 0
	while placed.size() < count and attempts < 500:
		attempts += 1
		var pos: Vector2 = Vector2(rng.randf_range(-1150.0, 1150.0), rng.randf_range(-1150.0, 1150.0))
		if pos.length() < 340.0:
			continue # Точку старта игрока оставляем чистой
		var too_close: bool = false
		for other in placed:
			if pos.distance_to(other) < 430.0:
				too_close = true
				break
		if too_close:
			continue
		placed.append(pos)
		var zone = SlowZoneScene.instantiate()
		zone.configure(rng.randf_range(135.0, 190.0), 0.55)
		zone.position = pos
		m.add_child(zone)
		slow_zones.append(zone)

# ── Ловушки арены: метеорит или шипы рядом с игроком плюс метеоритный дождь.
func spawn_hazard() -> void:
	# Ловушка появляется рядом с игроком: от неё нужно уходить, но и толпу она бьёт.
	var angle: float = randf() * TAU
	var distance: float = randf_range(110.0, 300.0)
	var pos: Vector2 = m.player.global_position + Vector2(cos(angle), sin(angle)) * distance
	pos.x = clampf(pos.x, -1520.0, 1520.0)
	pos.y = clampf(pos.y, -1520.0, 1520.0)
	var hazard = HazardScene.instantiate()
	if randf() < 0.6:
		hazard.configure("meteor", 110.0, 25, 60, 0.9) # телеграф 0.9 с — успеваешь выйти
	else:
		hazard.configure("spikes", 85.0, 6, 16, 0.55)
	hazard.position = pos
	m.add_child(hazard)

func spawn_meteor_shower() -> void:
	m.hud.announce(Loc.t("МЕТЕОРИТНЫЙ ДОЖДЬ!"), Color(1.0, 0.55, 0.25), 28)
	AudioManager.play("explosion", -10.0)
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + randf() * 0.4
		var pos: Vector2 = m.player.global_position + Vector2(cos(angle), sin(angle)) * randf_range(150.0, 340.0)
		pos.x = clampf(pos.x, -1520.0, 1520.0)
		pos.y = clampf(pos.y, -1520.0, 1520.0)
		var hazard = HazardScene.instantiate()
		hazard.configure("meteor", randf_range(95.0, 130.0), 25, 60, 1.3)
		hazard.position = pos
		m.add_child(hazard)
