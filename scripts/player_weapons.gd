extends Node
class_name PlayerWeapons
## Система оружия игрока: таймеры перезарядки и каст каждого заклинания.
##
## Вынесено из player.gd (фаза B рефакторинга). Узел — дочерний к игроку,
## ссылку на хозяина держит в `p`, поэтому:
##   • пауза наследуется автоматически (process_mode у игрока — PAUSABLE);
##   • статы остаются в player.gd, здесь только чтение через `p` (иначе система
##     улучшений, которая пишет их через set(stat, …) по имени, перестала бы работать).
## Добавлять новое заклинание: статы — в player.gd, стрельбу — сюда, каст — в tick().

# ── Сцены снарядов: preload один раз на старте, чтобы не грузить ресурс на каждый выстрел.
const OrbitBladeScene: PackedScene = preload("res://scenes/orbit_blade.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/projectile.tscn")
const NovaRingScene: PackedScene = preload("res://scenes/nova_ring.tscn")
const LightningBoltScene: PackedScene = preload("res://scenes/lightning_bolt.tscn")
const FireballScene: PackedScene = preload("res://scenes/fireball.tscn")
const BoomerangScene: PackedScene = preload("res://scenes/boomerang.tscn")
const SpearScene: PackedScene = preload("res://scenes/spear.tscn")
const MineScene: PackedScene = preload("res://scenes/mine.tscn")
const PoisonCloudScene: PackedScene = preload("res://scenes/poison_cloud.tscn")
const SawScene: PackedScene = preload("res://scenes/saw.tscn")

const ORBIT_RADIUS: float = 72.0
## Стрелы: своя картинка и золотистый след вместо синего магического шара.
const ARROW_SPRITE: String = "fx_arrow"
const ARROW_COLOR := Color(1.0, 0.84, 0.42)

## Хозяин: игрок (CharacterBody2D). Ставится из player.gd в _ready.
var p = null

# ── Таймеры перезарядки: тикают в tick(), на нуле — каст заклинания.
var bolt_timer: float = 0.0
var nova_timer: float = 1.2
var chain_timer: float = 0.6
var fire_timer: float = 0.4
var frost_timer: float = 0.5
var boom_timer: float = 0.8
var spear_timer: float = 0.4
var mine_timer: float = 0.8
var poison_timer: float = 1.0
var saw_timer: float = 1.4

# ── Главный цикл оружия: вызывается из player.gd::_physics_process каждый кадр.
## Порядок блоков совпадает с порядком заклинаний в данных; каждое открытое
## заклинание уменьшает свой таймер и на нуле делает выстрел/каст.
func tick(delta: float) -> void:
	if p == null or p.dead:
		return
	# Магические снаряды (лук лучника)
	if p.unlocked_weapons.has("bolt"):
		bolt_timer -= delta
		if bolt_timer <= 0.0:
			try_fire_bolt()
			bolt_timer = p.bolt_cooldown
	# Клинки на орбите: вращение пивота, у эволюции «Вихрь» радиус дышит
	if p.unlocked_weapons.has("orbit"):
		p.orbit_pivot.rotation += p.orbit_rotation_speed * delta
		if p.has_evo("evo_orbit"):
			# «Вихрь»: радиус орбиты дышит, клинки прочёсывают большую площадь.
			var wave: float = 1.0 + sin(float(Time.get_ticks_msec()) / 520.0) * 0.55
			p.orbit_pivot.scale = Vector2(wave, wave)
	# Нова по площади
	if p.unlocked_weapons.has("nova"):
		nova_timer -= delta
		if nova_timer <= 0.0:
			trigger_nova()
			nova_timer = p.nova_cooldown
	# Цепная молния
	if p.unlocked_weapons.has("chain"):
		chain_timer -= delta
		if chain_timer <= 0.0:
			trigger_chain()
			chain_timer = p.chain_cooldown
	# Огненный шар
	if p.unlocked_weapons.has("fireball"):
		fire_timer -= delta
		if fire_timer <= 0.0:
			try_fire_fireball()
			fire_timer = p.fire_cooldown
	# Ледяная аура: сама аура — это визуальный круг игрока, тик урона — раз в 0.5 с
	if p.unlocked_weapons.has("frost"):
		p.frost_visual.visible = true
		p.frost_visual.scale = Vector2.ONE * (p.scaled_area(p.frost_radius) / 130.0)
		p.frost_visual.modulate.a = 0.10 + sin(float(Time.get_ticks_msec()) / 300.0) * 0.04
		frost_timer -= delta
		if frost_timer <= 0.0:
			frost_tick()
			frost_timer = 0.5
	# Бумеранг
	if p.unlocked_weapons.has("boomerang"):
		boom_timer -= delta
		if boom_timer <= 0.0:
			try_throw_boomerang()
			boom_timer = p.boom_cooldown
	# Копьё
	if p.unlocked_weapons.has("spear"):
		spear_timer -= delta
		if spear_timer <= 0.0:
			try_throw_spear()
			spear_timer = p.spear_cooldown
	# Мины
	if p.unlocked_weapons.has("mine"):
		mine_timer -= delta
		if mine_timer <= 0.0:
			drop_mine()
			mine_timer = p.mine_cooldown
	# Ядовитое облако
	if p.unlocked_weapons.has("poison"):
		poison_timer -= delta
		if poison_timer <= 0.0:
			cast_poison()
			poison_timer = p.poison_cooldown
	# Пила
	if p.unlocked_weapons.has("saw"):
		saw_timer -= delta
		if saw_timer <= 0.0:
			throw_saw()
			saw_timer = p.saw_cooldown

# ── Стрельба: по функции на заклинание, каждая сама ищет цель и спавнит снаряд.
func try_fire_bolt() -> void:
	# Каждый снаряд выбирает СВОЮ ближайшую цель (как в Vampire Survivors),
	# чтобы несколько снарядов не летели в одну точку и не теряли урон.
	var targets: Array = []
	var bolt_range_now: float = p.scaled_area(p.bolt_range)
	var bolt_damage_now: int = p.scaled_damage(p.bolt_damage)
	# Пробитие — обычная стата: карта «Пробитие +1» до 4, эволюция «Залп» снимает предел.
	var pierce_count: int = p.bolt_pierce
	var spread_step: float = 0.22 if p.has_evo("evo_bolt") else 0.14
	for i in range(p.bolt_count):
		var target = p.find_nearest_enemy(targets, bolt_range_now)
		if target == null:
			# Все цели в радиусе уже назначены — остальные снаряды в ближайшую.
			target = p.find_nearest_enemy([], bolt_range_now)
		if target == null:
			return # Врагов в радиусе нет — не стреляем
		targets.append(target)
		var base_angle: float = (target.global_position - p.global_position).angle()
		var spread: float = (float(i) - float(p.bolt_count - 1) / 2.0) * spread_step
		var angle: float = base_angle + spread
		var dir: Vector2 = Vector2.from_angle(angle)
		# Разносим точки спавна вбок, чтобы снаряды не стартовали из одной точки.
		var side_offset: float = (float(i) - float(p.bolt_count - 1) / 2.0) * 20.0
		var spawn_pos: Vector2 = p.global_position + dir * 20.0 + Vector2(-dir.y, dir.x) * side_offset
		var projectile = ProjectileScene.instantiate()
		projectile.configure(angle, bolt_damage_now, p.bolt_speed, pierce_count, spawn_pos, bolt_range_now,
			p.bolt_ricochet, p.bolt_homing, ARROW_SPRITE, ARROW_COLOR)
		get_tree().current_scene.call_deferred("add_child", projectile)
	AudioManager.play("shoot", -10.0)

func trigger_nova() -> void:
	AudioManager.play("nova", -6.0)
	FX.shake(0.3, 4.0)
	var radius: float = p.scaled_area(p.nova_radius)
	var dmg: int = p.scaled_damage(p.nova_damage)
	var ring = NovaRingScene.instantiate()
	ring.configure(radius, p.global_position)
	get_tree().current_scene.call_deferred("add_child", ring)
	var dealt: int = 0
	for enemy in Enemies.all():
		if p.global_position.distance_to(enemy.global_position) <= radius:
			enemy.call("take_damage", dmg, p.global_position, "nova")
			dealt += dmg
	# «Взрывная волна»: вампиризм с нанесённого урона.
	if p.has_evo("evo_nova") and dealt > 0:
		p.heal(maxi(1, int(float(dealt) * 0.05)))

func trigger_chain() -> void:
	AudioManager.play("lightning", -8.0)
	var search_range: float = 900.0 if p.has_evo("evo_chain") else p.scaled_area(p.chain_range)
	var first = p.find_nearest_enemy([], search_range)
	if first == null:
		return
	var hit: Array = []
	var points: Array = [p.global_position]
	var current = first
	var prev_pos: Vector2 = p.global_position
	while current != null and hit.size() <= p.chain_jumps:
		hit.append(current)
		points.append(current.global_position)
		# Урон затухает с каждой цепью: 100% -> 80% -> 64% -> ...
		var dmg: int = maxi(1, int(float(p.scaled_damage(p.chain_damage)) * pow(0.8, float(hit.size() - 1))))
		current.call("take_damage", dmg, prev_pos, "chain")
		prev_pos = current.global_position
		current = find_chain_next(prev_pos, hit)
	var bolt = LightningBoltScene.instantiate()
	bolt.configure(points)
	get_tree().current_scene.call_deferred("add_child", bolt)

## Следующая цель для перескока молнии: ближайший враг в радиусе прыжка, кроме уже задетых.
func find_chain_next(from_pos: Vector2, exclude: Array):
	var best = null
	var best_dist: float = 999999999.0
	var jump_range: float = p.scaled_area(p.chain_jump_range)
	var max_sq: float = jump_range * jump_range
	for enemy in Enemies.all():
		if exclude.has(enemy) or enemy.is_queued_for_deletion():
			continue
		var d: float = from_pos.distance_squared_to(enemy.global_position)
		if d < best_dist and d <= max_sq:
			best_dist = d
			best = enemy
	return best

func try_fire_fireball() -> void:
	var targets: Array = []
	for i in range(p.fire_count):
		var target = p.find_nearest_enemy(targets, p.bolt_range)
		if target == null:
			target = p.find_nearest_enemy([], p.bolt_range)
		if target == null:
			return
		targets.append(target)
		var base_angle: float = (target.global_position - p.global_position).angle()
		var spread: float = (float(i) - float(p.fire_count - 1) / 2.0) * 0.14
		var angle: float = base_angle + spread
		var dir: Vector2 = Vector2.from_angle(angle)
		var side_offset: float = (float(i) - float(p.fire_count - 1) / 2.0) * 20.0
		var spawn_pos: Vector2 = p.global_position + dir * 20.0 + Vector2(-dir.y, dir.x) * side_offset
		var dmg: int = p.scaled_damage(p.fire_damage)
		var radius: float = p.scaled_area(p.fire_radius)
		if p.has_evo("evo_fire"):
			dmg = int(round(float(dmg) * 1.4))
			radius *= 1.8
		var fireball = FireballScene.instantiate()
		fireball.configure(angle, dmg, 460.0, radius, spawn_pos)
		get_tree().current_scene.call_deferred("add_child", fireball)
	AudioManager.play("shoot", -10.0, 0.7)

## Тик ледяной ауры: замедление и урон всем врагам в радиусе.
func frost_tick() -> void:
	var radius: float = p.scaled_area(p.frost_radius)
	var dmg: int = p.scaled_damage(p.frost_damage)
	for enemy in Enemies.all():
		if p.global_position.distance_to(enemy.global_position) <= radius:
			enemy.set("slow_timer", 0.6)
			enemy.set("slow_factor", p.frost_slow)
			enemy.call("take_damage", dmg, p.global_position, "frost")

func try_throw_boomerang() -> void:
	var target = p.find_nearest_enemy([], p.bolt_range)
	if target == null:
		return
	var base_angle: float = (target.global_position - p.global_position).angle()
	for i in range(p.boom_count):
		var spread: float = (float(i) - float(p.boom_count - 1) / 2.0) * 0.35
		var angle: float = base_angle + spread
		var dir: Vector2 = Vector2.from_angle(angle)
		var boom = BoomerangScene.instantiate()
		boom.configure(angle, p.scaled_damage(p.boom_damage), 430.0, p.scaled_area(p.boom_range), p.global_position + dir * 20.0)
		get_tree().current_scene.call_deferred("add_child", boom)
	AudioManager.play("boomerang", -8.0)

func try_throw_spear() -> void:
	var search_range: float = p.scaled_area(p.spear_range)
	var target = p.find_nearest_enemy([], search_range)
	if target == null:
		return
	var base_angle: float = (target.global_position - p.global_position).angle()
	for i in range(p.spear_count):
		var spread: float = (float(i) - float(p.spear_count - 1) / 2.0) * 0.12
		var angle: float = base_angle + spread
		var dir: Vector2 = Vector2.from_angle(angle)
		var spear = SpearScene.instantiate()
		spear.configure(angle, p.scaled_damage(p.spear_damage), p.spear_speed, search_range, p.global_position + dir * 24.0)
		get_tree().current_scene.call_deferred("add_child", spear)
	AudioManager.play("boomerang", -12.0, 1.35)

func drop_mine() -> void:
	for i in range(p.mine_count):
		var angle: float = TAU * float(i) / float(maxi(p.mine_count, 1)) + randf() * 0.4
		var pos: Vector2 = p.global_position + Vector2(cos(angle), sin(angle)) * 28.0
		var mine = MineScene.instantiate()
		mine.configure(p.scaled_damage(p.mine_damage), p.scaled_area(p.mine_radius), pos)
		get_tree().current_scene.call_deferred("add_child", mine)
	AudioManager.play("click", -16.0, 0.55)

func cast_poison() -> void:
	var pos: Vector2 = p.global_position
	var target = p.find_nearest_enemy([], p.scaled_area(p.bolt_range))
	if target != null:
		pos = target.global_position
	var cloud = PoisonCloudScene.instantiate()
	cloud.configure(p.scaled_damage(p.poison_damage), p.scaled_area(p.poison_radius), p.poison_duration, pos)
	get_tree().current_scene.call_deferred("add_child", cloud)
	AudioManager.play("nova", -16.0, 0.55)

func throw_saw() -> void:
	for i in range(p.saw_count):
		var saw = SawScene.instantiate()
		saw.configure(p.scaled_damage(p.saw_damage), p.scaled_area(p.saw_radius), p.global_position)
		get_tree().current_scene.call_deferred("add_child", saw)
	AudioManager.play("boomerang", -14.0, 0.75)

# ── Клинки на орбите: пересборка узлов после смены количества, размера или урона.
func rebuild_orbit_blades() -> void:
	for child in p.orbit_pivot.get_children():
		p.orbit_pivot.remove_child(child)
		child.queue_free()
	if not p.unlocked_weapons.has("orbit"):
		return
	for i in range(p.orbit_blade_count):
		var blade = OrbitBladeScene.instantiate()
		blade.damage = p.scaled_damage(p.orbit_damage)
		blade.scale = Vector2(p.orbit_blade_size, p.orbit_blade_size)
		p.orbit_pivot.add_child(blade)
		var angle: float = TAU * float(i) / float(p.orbit_blade_count)
		blade.position = Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
		blade.rotation = angle + PI / 2.0

## Клинки держат урон у себя, поэтому после прокачки его надо разослать по узлам.
func refresh_orbit_damage() -> void:
	for blade in p.orbit_pivot.get_children():
		blade.damage = p.scaled_damage(p.orbit_damage)

## Новый размер клинков — без пересборки, только масштаб.
func apply_orbit_size() -> void:
	for blade in p.orbit_pivot.get_children():
		blade.scale = Vector2(p.orbit_blade_size, p.orbit_blade_size)
