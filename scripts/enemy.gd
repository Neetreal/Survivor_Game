extends Area2D
## Враг: преследует игрока, получает урон, дропает кристалл опыта.

const GemScene: PackedScene = preload("res://scenes/xp_gem.tscn")
const ChestScene: PackedScene = preload("res://scenes/chest.tscn")
const EnemyProjectileScene: PackedScene = preload("res://scenes/enemy_projectile.tscn")
const NovaRingScene: PackedScene = preload("res://scenes/nova_ring.tscn")

## Лекари: лечат мало, не лечат других лекарей, а объём лечения на одного врага
## ограничен — причём лимит растёт вместе с длительностью забега.
const HEAL_RADIUS: float = 175.0
const HEAL_INTERVAL: float = 2.5
const HEAL_PERCENT: float = 0.04 # Доля макс. HP за тик (было 0.1)
const HEAL_MIN: int = 2
const HEAL_CAP_BASE: float = 0.2 # Потолок полученного лечения: 20% HP в начале забега
const HEAL_CAP_PER_MINUTE: float = 0.06 # +6% HP за каждую минуту забега
const HEAL_CAP_MAX: float = 0.6 # Но не больше 60% HP

## Рост пожирателя кристаллов ограничен, чтобы он не перерастал босса.
const BOSS_SCALE: float = 3.2 # Размер главного босса
const EATER_MAX_SCALE_RATIO: float = 0.7 # Пожиратель не больше 70% босса (2.24 при боссе 3.2)
const EATER_MAX_GROWTH: int = 50 # После 50 кристаллов рост параметров прекращается
const EATER_MAX_HP: int = 300 # Потолок здоровья раскормленного пожирателя
const EATER_MAX_XP: int = 60 # Потолок опыта за «раскормленного» пожирателя
const DamageNumberScene: PackedScene = preload("res://scenes/damage_number.tscn")

var enemy_type: String = "slime"
var max_hp: int = 20
var hp: int = 20
var speed: float = 70.0
var damage: int = 8
var xp_value: int = 1

var knockback_velocity: Vector2 = Vector2.ZERO
var orbit_cooldown: float = 0.0
var boomerang_cooldown: float = 0.0
var slow_timer: float = 0.0
var slow_factor: float = 0.5
var shoot_timer: float = 1.0
# Атаки босса
var burst_timer: float = 2.0
var dash_timer: float = 4.0
var summon_timer: float = 6.0
var attack_state: String = "chase" # chase / telegraph / dash / recover
var state_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var flash_timer: float = 0.0
var player = null
# Мини-боссы: своё имя, особая атака и отдельная группа для полоски HP.
var is_mini_boss: bool = false
var mini_boss_name: String = ""
var special: String = ""
var special_timer: float = 2.0
# Щитоносец: сколько попаданий гасит щит
var shield_hits: int = 0
# Вектор отталкивания от соседей, считается один раз за кадр в main.gd (сетка)
var separation_push: Vector2 = Vector2.ZERO
# LOD: враг в пределах экрана. За экраном он просто идёт к игроку — расталкивание,
# «спец»-логика и анимация не считаются (см. _is_on_screen и main.update_separation).
var on_screen: bool = true
var lod_timer: float = 0.0
# Лекарь
var heal_timer: float = 2.5
# Сколько всего вылечили этому врагу (лекари больше не бесконечный источник HP)
var healed_taken: int = 0
# Пожиратель кристаллов
var gem_scan_timer: float = 0.0
var eat_target = null
var eaten_gems: int = 0

var pending_type: String = "slime"
var pending_hp_multiplier: float = 1.0
var pending_damage_multiplier: float = 1.0
var pending_speed_multiplier: float = 1.0
var pending_position: Vector2 = Vector2.ZERO

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body
## Базовый цвет типа врага: им красятся частицы и запасной кружок.
var body_color: Color = Color(0.45, 0.85, 0.35)
## Враг уже погиб. Без этого флага повторный урон по трупу снова вызывал die():
## бомбардир рядом взрывался, бил первого, тот «умирал» заново и взрывался снова —
## и так до переполнения стека (ровно этот краш ловился в игре).
var dead: bool = false
## Постоянный оттенок поверх спрайта (кормление пожирателя, сломанный щит).
var tint: Color = Color.WHITE
var _bob_phase: float = 0.0
## Покадровый шаг: base → walk1 → base → walk2 (как у героев).
var walk_frames: Array = []
var _frame_time: float = 0.0
var _frame_index: int = 0
const ENEMY_WALK_FPS: float = 8.0

# ── LOD за экраном: как часто проверяем видимость и какой запас считаем «экраном».
# Запас важнее частоты: за интервал враг не должен успеть влететь в кадр с замороженной
# анимацией. Самый быстрый — рывок босса 450 px/с, это 68 px за 0.15 с < 160 px запаса.
const LOD_CHECK_INTERVAL: float = 0.15
const LOD_MARGIN: float = 160.0

func configure(type: String, hp_multiplier: float, spawn_position: Vector2, damage_multiplier: float = 1.0, speed_multiplier: float = 1.0) -> void:
	pending_type = type
	pending_hp_multiplier = hp_multiplier
	pending_damage_multiplier = damage_multiplier
	pending_speed_multiplier = speed_multiplier
	pending_position = spawn_position

func _exit_tree() -> void:
	# Снимаем с учёта ровно там же, где Godot убирает из группы.
	Enemies.unregister(self)

func _ready() -> void:
	# См. player.gd: без явного PAUSABLE враг унаследует ALWAYS от Main и не встанет на паузу.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	Enemies.register(self)
	enemy_type = pending_type
	apply_type_stats()
	if enemy_type == "boss":
		add_to_group("boss")
	elif is_mini_boss:
		add_to_group("miniboss")
	global_position = pending_position
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func apply_type_stats() -> void:
	var base_hp: int = 20
	var base_speed: float = 70.0
	var base_damage: int = 8
	var base_xp: int = 1
	var enemy_scale: float = 1.0
	var enemy_color: Color = Color(0.45, 0.85, 0.35)
	match enemy_type:
		"slime":
			base_hp = 20
			base_speed = 72.0
			base_damage = 8
			base_xp = 1
			enemy_scale = 1.0
			enemy_color = Color(0.45, 0.85, 0.35)
		"bat":
			base_hp = 12
			base_speed = 135.0
			base_damage = 6
			base_xp = 1
			enemy_scale = 0.8
			enemy_color = Color(0.65, 0.45, 0.95)
		"brute":
			base_hp = 95
			base_speed = 52.0
			base_damage = 18
			base_xp = 5
			enemy_scale = 1.6
			enemy_color = Color(0.95, 0.55, 0.25)
		"elite":
			base_hp = 420
			base_speed = 62.0
			base_damage = 26
			base_xp = 20
		"spitter":
			base_hp = 30
			base_speed = 68.0
			base_damage = 8
			base_xp = 2
			enemy_scale = 1.0
			enemy_color = Color(0.2, 0.75, 0.6)
		"splitter":
			base_hp = 45
			base_speed = 58.0
			base_damage = 10
			base_xp = 2
			enemy_scale = 1.3
			enemy_color = Color(0.95, 0.5, 0.7)
		"boss":
			base_hp = 550
			base_speed = 55.0
			base_damage = 30
			base_xp = 50
			enemy_scale = BOSS_SCALE
			enemy_color = Color(0.95, 0.25, 0.3)
		"shieldbearer":
			base_hp = 70
			base_speed = 48.0
			base_damage = 14
			base_xp = 3
			enemy_scale = 1.25
			enemy_color = Color(0.55, 0.62, 0.78)
			shield_hits = 4
		"bomber":
			base_hp = 26
			base_speed = 96.0
			base_damage = 22
			base_xp = 2
			enemy_scale = 1.1
			enemy_color = Color(0.95, 0.55, 0.15)
		"healer":
			base_hp = 55
			base_speed = 60.0
			base_damage = 8
			base_xp = 4
			enemy_scale = 1.15
			enemy_color = Color(0.35, 0.9, 0.5)
		"gem_eater":
			base_hp = 40
			base_speed = 74.0
			base_damage = 10
			base_xp = 3
			enemy_scale = 1.0
			enemy_color = Color(0.85, 0.75, 0.35)
		"mb_slime":
			base_hp = 900
			base_speed = 58.0
			base_damage = 22
			base_xp = 30
			enemy_scale = 2.4
			enemy_color = Color(0.25, 0.72, 0.38)
			is_mini_boss = true
			special = "summon"
			mini_boss_name = "Кровавый слизень"
		"mb_bat":
			base_hp = 560
			base_speed = 108.0
			base_damage = 18
			base_xp = 28
			enemy_scale = 2.0
			enemy_color = Color(0.75, 0.35, 0.95)
			is_mini_boss = true
			special = "blink"
			mini_boss_name = "Король летучих мышей"
		"mb_brute":
			base_hp = 1250
			base_speed = 46.0
			base_damage = 30
			base_xp = 35
			enemy_scale = 2.2
			enemy_color = Color(0.95, 0.5, 0.2)
			is_mini_boss = true
			special = "burst"
			mini_boss_name = "Громила-вождь"
		"mb_spitter":
			base_hp = 700
			base_speed = 66.0
			base_damage = 20
			base_xp = 30
			enemy_scale = 1.9
			enemy_color = Color(0.2, 0.85, 0.7)
			is_mini_boss = true
			special = "spit"
			mini_boss_name = "Токсичный матриарх"
	max_hp = maxi(1, int(float(base_hp) * pending_hp_multiplier))
	hp = max_hp
	speed = base_speed * pending_speed_multiplier
	damage = maxi(1, int(round(float(base_damage) * pending_damage_multiplier)))
	xp_value = maxi(1, int(round(float(base_xp) * Records.difficulty_value("xp"))))
	scale = Vector2(enemy_scale, enemy_scale)
	body_color = enemy_color
	apply_body_sprite()

func _physics_process(delta: float) -> void:
	if orbit_cooldown > 0.0:
		orbit_cooldown -= delta
	if boomerang_cooldown > 0.0:
		boomerang_cooldown -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			set_flash(Color.WHITE)
	# LOD: видимость проверяем редко — шесть раз в секунду вместо каждого кадра.
	lod_timer -= delta
	if lod_timer <= 0.0:
		# Небольшой разброс: враги не проверяются все в одном кадре.
		lod_timer = LOD_CHECK_INTERVAL * randf_range(0.85, 1.15)
		on_screen = _is_on_screen()
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_player: Vector2 = player.global_position - global_position
	var dir: Vector2 = Vector2.ZERO
	if to_player.length() > 1.0:
		dir = to_player.normalized()
	# Пожиратель кристаллов охотится за опытом, а не за игроком (только в пределах экрана).
	if enemy_type == "gem_eater" and on_screen:
		gem_scan_timer -= delta
		if gem_scan_timer <= 0.0:
			gem_scan_timer = 0.3
			eat_target = find_nearest_gem(460.0)
		if eat_target != null and is_instance_valid(eat_target):
			var to_gem: Vector2 = eat_target.global_position - global_position
			if to_gem.length() < 28.0:
				eat_gem(eat_target)
				eat_target = null
			else:
				dir = to_gem.normalized()
	# Лекарь время от времени лечит соседей — это видно, только когда он на экране.
	if enemy_type == "healer" and on_screen:
		healer_tick(delta)
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, clampf(8.0 * delta, 0.0, 1.0))
	# У мини-босса своя «фишка», и она работает даже за экраном — иначе от него не убежать.
	if is_mini_boss:
		mini_boss_special(delta)
	# Разделение: вектор готовит main.update_separation по сетке — только для видимых.
	var separation: Vector2 = calculate_separation() if on_screen else Vector2.ZERO
	var effective_speed: float = speed * (slow_factor if slow_timer > 0.0 else 1.0)
	var velocity: Vector2
	if enemy_type == "boss":
		velocity = boss_movement(delta, dir, separation, effective_speed)
	elif enemy_type == "spitter" and on_screen:
		# Плевун держит дистанцию и стреляет издалека.
		var dist_to_player: float = to_player.length()
		var move_dir: Vector2 = Vector2.ZERO
		if dist_to_player > 280.0:
			move_dir = dir
		elif dist_to_player < 200.0:
			move_dir = -dir
		velocity = move_dir * effective_speed + separation * 110.0 + knockback_velocity
		shoot_timer -= delta
		if shoot_timer <= 0.0 and dist_to_player < 440.0:
			shoot_timer = 2.2
			shoot_at_player(dir)
	else:
		velocity = dir * effective_speed + separation * 110.0 + knockback_velocity
	global_position += velocity * delta
	# Пульсация и покадровая анимация нужны только там, где их видно.
	if on_screen:
		var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) / 180.0 + float(get_instance_id() % 10)) * 0.06
		if enemy_type == "boss" and attack_state == "telegraph":
			pulse = 1.18 + sin(float(Time.get_ticks_msec()) / 40.0) * 0.08 # Дрожь перед рывком
		visual.scale = Vector2(pulse, pulse)
		body.scale = Vector2(pulse, pulse)
		_animate_body(delta)

func boss_movement(delta: float, dir: Vector2, separation: Vector2, effective_speed: float) -> Vector2:
	# Атака 1: кольцо снарядов во все стороны.
	burst_timer -= delta
	if burst_timer <= 0.0:
		burst_timer = 3.5
		fire_radial_burst()
	# Атака 3: призыв слаймов.
	summon_timer -= delta
	if summon_timer <= 0.0:
		summon_timer = 8.0
		summon_minions()
	# Атака 2: рывок с телеграфом.
	if attack_state == "chase":
		dash_timer -= delta
		if dash_timer <= 0.0:
			attack_state = "telegraph"
			state_timer = 0.5
			dash_dir = dir # Направление фиксируем сразу — игроку можно увернуться
		return dir * effective_speed + separation * 110.0 + knockback_velocity
	elif attack_state == "telegraph":
		state_timer -= delta
		if state_timer <= 0.0:
			attack_state = "dash"
			state_timer = 0.55
		return knockback_velocity
	elif attack_state == "dash":
		state_timer -= delta
		if state_timer <= 0.0:
			attack_state = "recover"
			state_timer = 0.4
			dash_timer = 5.5
		return dash_dir * 450.0 + knockback_velocity
	else: # recover
		state_timer -= delta
		if state_timer <= 0.0:
			attack_state = "chase"
		return dir * effective_speed * 0.3 + knockback_velocity

func fire_radial_burst(count: int = 12) -> void:
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var proj = EnemyProjectileScene.instantiate()
		proj.configure(angle, maxi(1, int(round(12.0 * pending_damage_multiplier))), 260.0, global_position)
		get_tree().current_scene.call_deferred("add_child", proj)

func find_nearest_gem(max_distance: float):
	var best = null
	var best_dist: float = max_distance * max_distance
	for gem in get_tree().get_nodes_in_group("gems"):
		if gem.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_squared_to(gem.global_position)
		if d < best_dist:
			best_dist = d
			best = gem
	return best

func eat_gem(gem) -> void:
	# Пожиратель растёт и становится злее с каждым съеденным кристаллом.
	if gem == null or not is_instance_valid(gem):
		return
	var value: int = int(gem.get("gem_value"))
	gem.queue_free()
	eaten_gems += 1
	# Опыт за убийство растёт всегда — это награда за риск.
	xp_value = mini(xp_value + maxi(1, value), EATER_MAX_XP)
	# А вот размер и сила — только до предела: перерасти босса он не может.
	if eaten_gems <= EATER_MAX_GROWTH:
		var max_scale: float = BOSS_SCALE * EATER_MAX_SCALE_RATIO
		max_hp = mini(max_hp + 6 + value, EATER_MAX_HP)
		hp = mini(hp + 6 + value, max_hp)
		scale = Vector2(minf(scale.x + 0.03, max_scale), minf(scale.y + 0.03, max_scale))
		speed = minf(speed + 1.0, 130.0)
		lerp_tint(Color(1.0, 0.85, 0.3), 0.15)
	AudioManager.play("gem", -16.0, 0.7)
	FX.burst(global_position, Color(0.9, 0.8, 0.35), 6, 70.0)

## Потолок лечения для этого врага: растёт со временем забега.
func heal_cap() -> int:
	var minutes: float = 0.0
	var game = get_tree().get_first_node_in_group("game")
	if game != null:
		minutes = float(game.get("elapsed_time")) / 60.0
	var ratio: float = minf(HEAL_CAP_BASE + HEAL_CAP_PER_MINUTE * minutes, HEAL_CAP_MAX)
	return maxi(HEAL_MIN, int(float(max_hp) * ratio))

## Сколько ещё можно вылечить этому врагу (0 — лимит исчерпан).
func heal_room() -> int:
	return maxi(0, heal_cap() - healed_taken)

## Возвращает, сколько HP реально восстановлено.
func heal_enemy(amount: int) -> int:
	if hp >= max_hp:
		return 0
	var actual: int = mini(mini(amount, heal_room()), max_hp - hp)
	if actual <= 0:
		return 0
	hp += actual
	healed_taken += actual
	spawn_heal_number(actual)
	return actual

func spawn_heal_number(amount: int) -> void:
	var dn = DamageNumberScene.instantiate()
	dn.call("configure_heal", amount, global_position + Vector2(randf_range(-8.0, 8.0), -20.0))
	var game = get_tree().get_first_node_in_group("game")
	if game != null:
		game.call_deferred("add_child", dn)

func healer_tick(delta: float) -> void:
	heal_timer -= delta
	if heal_timer > 0.0:
		return
	heal_timer = HEAL_INTERVAL
	var healed_total: int = 0
	var healed_count: int = 0
	for other in Enemies.all():
		if other == self or other.is_queued_for_deletion():
			continue
		# Лекари не лечат лекарей — иначе пара целителей держала бы друг друга вечно.
		if str(other.get("enemy_type")) == "healer":
			continue
		if global_position.distance_to(other.global_position) > HEAL_RADIUS:
			continue
		if not other.has_method("heal_enemy"):
			continue
		var amount: int = maxi(HEAL_MIN, int(float(other.get("max_hp")) * HEAL_PERCENT))
		var actual: int = int(other.call("heal_enemy", amount))
		if actual > 0:
			healed_total += actual
			healed_count += 1
	if healed_count > 0:
		FX.burst(global_position, Color(0.4, 1.0, 0.5), 10, 95.0)
		AudioManager.play("gem", -20.0, 1.4)

func explode_on_death() -> void:
	# Бомбардир — «не убивай меня рядом с собой».
	AudioManager.play("explosion", -6.0)
	FX.burst(global_position, Color(1.0, 0.6, 0.2), 26, 210.0)
	FX.shake(0.45, 4.0)
	var ring = NovaRingScene.instantiate()
	ring.configure(130.0, global_position, Color(1.0, 0.5, 0.15))
	get_tree().current_scene.call_deferred("add_child", ring)
	if player != null and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) < 130.0:
			player.call("take_damage", damage)
	# Цепная реакция: собираем цели и бьём их отложенно. Так взрывы идут каскадом
	# по кадрам, а не вложенными вызовами друг в друга (это и валило стек).
	var caught: Array = []
	for other in Enemies.all():
		if other == self or other.is_queued_for_deletion() or bool(other.get("dead")):
			continue
		if global_position.distance_to(other.global_position) < 130.0:
			caught.append(other)
	for other in caught:
		if is_instance_valid(other):
			other.call_deferred("take_damage", maxi(1, int(float(damage) * 0.5)), global_position, "other")

func mini_boss_special(delta: float) -> void:
	# У каждого мини-босса одна «фишка», которая заставляет игрока менять поведение.
	if player == null:
		return
	special_timer -= delta
	if special_timer > 0.0:
		return
	var dist: float = global_position.distance_to(player.global_position)
	match special:
		"summon":
			# Кровавый слизень постоянно плодит мелких слаймов.
			special_timer = 7.0
			summon_minions()
		"burst":
			# Громила бьёт кольцом снарядов — нельзя стоять рядом.
			special_timer = 3.5
			if dist < 560.0:
				fire_radial_burst(10)
		"spit":
			# Матриарх плюёт веером из трёх снарядов с дистанции.
			special_timer = 2.4
			if dist < 520.0:
				var aim: Vector2 = (player.global_position - global_position).normalized()
				for off in [-0.16, 0.0, 0.16]:
					var proj = EnemyProjectileScene.instantiate()
					var proj_damage: int = maxi(1, int(round(9.0 * pending_damage_multiplier)))
					proj.configure(aim.rotated(float(off)).angle(), proj_damage, 320.0, global_position)
					get_tree().current_scene.call_deferred("add_child", proj)
		"blink":
			# Король мышей телепортируется к игроку рывками.
			special_timer = 3.5
			if dist > 90.0:
				var jump: Vector2 = (player.global_position - global_position).normalized()
				FX.burst(global_position, visual.color, 16, 120.0)
				global_position += jump * minf(200.0, dist - 80.0)
				global_position.x = clampf(global_position.x, -1500.0, 1500.0)
				global_position.y = clampf(global_position.y, -1500.0, 1500.0)
				FX.burst(global_position, visual.color, 16, 120.0)

func summon_minions() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game == null or not game.has_method("spawn_enemy_at"):
		return
	# Уважаем лимит врагов, иначе призыв быстро зальёт экран.
	var alive: int = Enemies.count()
	var cap: int = int(game.get("max_enemies"))
	var allowed: int = maxi(0, cap - alive)
	for i in range(mini(4, allowed)):
		var angle: float = TAU * float(i) / 4.0 + randf() * 0.5
		var pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * 70.0
		game.call("spawn_enemy_at", "slime", pos)

func shoot_at_player(dir: Vector2) -> void:
	var proj = EnemyProjectileScene.instantiate()
	proj.configure(dir.angle(), maxi(1, int(round(10.0 * pending_damage_multiplier))), 300.0, global_position)
	get_tree().current_scene.call_deferred("add_child", proj)

## Спрайт по типу врага. Нет файла (мини-боссы, новые типы) — остаётся цветной кружок.
func apply_body_sprite() -> void:
	var type_id: String = enemy_type.trim_prefix("mb_")
	var path: String = "res://art/sprites/enemy_%s.png" % type_id
	if ResourceLoader.exists(path):
		body.texture = load(path)
		body.visible = true
		visual.visible = false
		_load_walk_frames(type_id)
	else:
		body.visible = false
		visual.visible = true
	apply_tint()

## Кадры шага врага: если рядом с базовым лежат <тип>_walk1 и <тип>_walk2 —
## собираем цикл. Нет кадров (желеобразные, паук) — работает процедурное покачивание.
func _load_walk_frames(type_id: String) -> void:
	walk_frames.clear()
	_frame_index = 0
	_frame_time = 0.0
	var first: String = "res://art/sprites/enemy_%s_walk1.png" % type_id
	var second: String = "res://art/sprites/enemy_%s_walk2.png" % type_id
	if ResourceLoader.exists(first) and ResourceLoader.exists(second):
		walk_frames = [body.texture, load(first), body.texture, load(second)]

## Постоянный оттенок: перемножается со вспышкой, поэтому вспышка остаётся видна.
func apply_tint() -> void:
	visual.color = body_color * tint
	body.self_modulate = tint

func set_tint(color: Color) -> void:
	tint = color
	apply_tint()

func lerp_tint(color: Color, weight: float) -> void:
	tint = tint.lerp(color, weight)
	apply_tint()

func set_flash(color: Color) -> void:
	visual.modulate = color
	body.modulate = color

## Анимация: покачивание в такт шагу и разворот по фактическому смещению.
## Фаза своя у каждого врага, иначе толпа дёргается синхронно.
## Направление берём из разницы позиций за кадр: у разных типов врагов
## скорость считается в разных ветках, а позиция меняется всегда.
var _last_position: Vector2 = Vector2.ZERO
var _has_last_position: bool = false

func _animate_body(delta: float) -> void:
	if not body.visible:
		return
	var moved: Vector2 = Vector2.ZERO
	if _has_last_position:
		moved = global_position - _last_position
		if absf(moved.x) > 0.05:
			body.flip_h = moved.x < 0.0
	_last_position = global_position
	_has_last_position = true

	if not walk_frames.is_empty():
		# Покадровый шаг: кадры меняются, только когда враг реально сместился
		# (в паузе, на телеграфе и в отталкивании по кругу он «стоит»).
		if moved.length() > 0.35:
			_frame_time += delta
			if _frame_time >= 1.0 / ENEMY_WALK_FPS:
				_frame_time = 0.0
				_frame_index = (_frame_index + 1) % walk_frames.size()
				body.texture = walk_frames[_frame_index]
			var lift: float = 1.0 if _frame_index % 2 == 1 else 0.0
			body.position.y = -lift * 1.5
		else:
			_frame_time = 0.0
			_frame_index = 0
			body.texture = walk_frames[0]
			body.position.y = 0.0
		body.rotation = 0.0
		return

	# Процедурное покачивание для тех, у кого нет кадров.
	_bob_phase += delta * (6.0 + speed * 0.05)
	var bob: float = absf(sin(_bob_phase + float(get_instance_id() % 7))) * 2.0
	body.position.y = -bob
	body.rotation = sin(_bob_phase) * 0.05

## Виден ли враг: сравниваем экранные координаты с прямоугольником экрана плюс запас.
## Экранные координаты берём у камеры, поэтому зум и сдвиг учитываются сами.
func _is_on_screen() -> bool:
	var screen_pos: Vector2 = get_global_transform_with_canvas().origin
	return get_viewport_rect().grow(LOD_MARGIN).has_point(screen_pos)

func calculate_separation() -> Vector2:
	# Готовый вектор отталкивания: его один раз за кадр считает main.gd
	# по сетке ячеек (см. update_separation). Полный перебор всех врагов
	# на каждого врага при лимите 120+ был бы слишком дорогим.
	return separation_push

func take_damage(amount: int, from_position: Vector2, source_id: String = "other") -> void:
	# По мёртвому врагу урон не проходит: иначе die() может войти повторно.
	if dead or is_queued_for_deletion():
		return
	# Щитоносец: первые попадания уходят в щит, урон не проходит.
	if shield_hits > 0:
		shield_hits -= 1
		AudioManager.play("hit", -18.0, 1.7)
		set_flash(Color(0.7, 0.95, 1.8))
		flash_timer = 0.08
		if shield_hits == 0:
			# Щит сломан — дальше враг уязвим и меняет цвет.
			FX.burst(global_position, Color(0.6, 0.85, 1.0), 16, 150.0)
			set_tint(Color(0.55, 0.6, 0.78))
		return
	AudioManager.play("hit", -12.0)
	# В зачёт идёт только реально прошедший урон: остаток HP, а не «заявленный».
	RunStats.add_damage(source_id, mini(amount, hp))
	hp -= amount
	var away: Vector2 = (global_position - from_position).normalized()
	knockback_velocity += away * 170.0 / scale.x
	set_flash(Color(3.0, 3.0, 3.0))
	flash_timer = 0.08
	spawn_damage_number(amount)
	if hp <= 0:
		die()

func spawn_damage_number(amount: int) -> void:
	# На низком качестве графики цифры урона отключены — меньше узлов и визуального шума.
	if not Records.quality_damage_numbers():
		return
	var dn = DamageNumberScene.instantiate()
	dn.configure(amount, global_position + Vector2(-8.0, -26.0))
	get_tree().current_scene.call_deferred("add_child", dn)

func die() -> void:
	if dead:
		return
	dead = true
	AudioManager.play("enemy_die", -8.0)
	var burst_amount: int = 12
	var burst_speed: float = 140.0
	if enemy_type == "boss":
		burst_amount = 40 # было 60: всё сверх бюджета FX всё равно срезалось
		burst_speed = 260.0
	elif is_mini_boss:
		burst_amount = 32 # было 40
		burst_speed = 220.0
	FX.burst(global_position, visual.color, burst_amount, burst_speed)
	if enemy_type == "bomber":
		explode_on_death()
	if enemy_type == "boss":
		FX.shake(1.0, 1.6)
		FX.hitstop(0.10, 0.15) # раньше 0.14 при time_scale 0.05 — читалось как зависание
	elif is_mini_boss:
		FX.shake(0.7, 2.2)
		FX.hitstop(0.06, 0.18)
	elif enemy_type == "elite":
		FX.shake(0.5, 2.5)
		FX.hitstop(0.04, 0.25)
	var game = get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_enemy_killed"):
		game.call("on_enemy_killed", self)
	var gem = GemScene.instantiate()
	gem.configure(xp_value, global_position)
	get_tree().current_scene.call_deferred("add_child", gem)
	# Элитный босс дополнительно дропает сундук с бесплатным улучшением.
	if enemy_type == "elite" or enemy_type == "boss" or is_mini_boss:
		var chest = ChestScene.instantiate()
		chest.configure(global_position + Vector2(36.0, 0.0))
		get_tree().current_scene.call_deferred("add_child", chest)
	queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", damage)
