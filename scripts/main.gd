extends Node2D
## Главная сцена: спавн врагов, таймер, сложность, пауза на улучшение, поражение.
## Main работает в режиме ALWAYS, чтобы принимать сигналы меню во время паузы,
## а внутри _process сам проверяет get_tree().paused.

# ── Сцены: враг, зона трясины, ловушка, ядро эволюции — preload один раз на старте.
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")
const SlowZoneScene: PackedScene = preload("res://scenes/slow_zone.tscn")
const HazardScene: PackedScene = preload("res://scenes/hazard.tscn")
const EvoCoreScene: PackedScene = preload("res://scenes/evo_core.tscn")

# ── Состояние забега: таймеры спавна, лимит врагов, флаги наград и победы.
var elapsed_time: float = 0.0
var kills: int = 0
var spawn_timer: float = 2.0
var elite_timer: float = 75.0
var event_timer: float = 60.0 # Кольцевое событие
var max_enemies: int = 60 # Лимит врагов на экране — защита от лагов (зависит от сложности)
var game_over: bool = false
var chest_reward_pending: bool = false
## Выбор открыт за ядро мини-босса: эволюция (evo) или замена (core).
## Уровень за такой выбор не тратится.
var evo_reward_pending: bool = false
var core_reward_pending: bool = false
var victory_shown: bool = false
var boss_spawned: bool = false
# Темп забега: мини-боссы каждые 2 минуты, волны-стаи каждые 45 секунд.
var miniboss_timer: float = 120.0
var stream_timer: float = 45.0
var wave_number: int = 0
# ── Переброс улучшений за золото: счётчик, цена и защита от двойного срабатывания.
var reroll_count: int = 0
var shatter_active: bool = false
# ── Достижения и профиль: счётчики забега и отметка «забег закрыт».
var miniboss_kills: int = 0
var achievement_timer: float = 2.0
var run_finished: bool = false
var slow_zones: Array = [] # Зоны трясины на текущей карте
# ── Карта: зоны трясины, ловушки арены, бонус золота.
var map_traps: bool = false
var trap_timer: float = 6.5
var shower_timer: float = 40.0
var map_gold_bonus: float = 1.0

# ── Узлы сцены: игрок и интерфейс.
@onready var player = $Player
@onready var hud = $HUD

# ── Старт забега: сложность, музыка, профиль, подписка на сигналы игрока и HUD.
func _ready() -> void:
	# Лимит врагов и таймеры — под выбранную сложность.
	max_enemies = int(Records.difficulty_value("enemy_cap"))
	Enemies.clear() # реестр врагов: начинаем забег с чистого листа
	elite_timer = Records.difficulty_value("elite_interval")
	AudioManager.play_music("battle")
	Records.start_run() # профиль: счётчик забегов и героев
	RunStats.reset() # экран результатов: урон по источникам и золото за забег
	apply_map()
	player.connect("died", _on_player_died)
	player.connect("leveled_up", _on_player_leveled_up)
	hud.connect("upgrade_chosen", _on_upgrade_chosen)
	hud.connect("restart_requested", _on_restart_requested)
	hud.connect("menu_requested", _on_menu_requested)
	hud.connect("spell_chosen", _on_spell_chosen)
	hud.connect("level5_chosen", _on_level5_chosen)
	hud.connect("continue_endless_requested", _on_continue_endless)
	hud.connect("victory_menu_requested", _on_victory_menu)
	hud.connect("reroll_requested", _on_reroll_requested)
	hud.update_kills(0)
	hud.update_timer(0.0)

# ── Кадр забега: таймер, появление босса, полоса HP, вспышка урона.
func _process(delta: float) -> void:
	if game_over or get_tree().paused:
		return
	elapsed_time += delta
	hud.update_timer(elapsed_time)
	# На 10-й минуте появляется босс — Победа только после его смерти.
	if not boss_spawned and elapsed_time >= 600.0:
		boss_spawned = true
		RunStats.boss_spawn_time = elapsed_time
		spawn_boss()
		AudioManager.play_music("boss")
		FX.shake(0.8, 1.5)
		FX.flash(Color(0.8, 0.05, 0.1), 0.25, 0.6)
		hud.set_boss_name("БОСС")
		hud.announce(Loc.t("БОСС!"), Color(1.0, 0.25, 0.3))
	# Полоса HP босса или мини-босса
	if boss_spawned and not victory_shown:
		update_boss_bar()
	elif not victory_shown:
		update_miniboss_bar()
	# ── Расписание спавна: у каждого события свой таймер (волна, элита, мини-босс, стая, ловушки, окружение).
	# Обычный спавн
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_wave()
		spawn_timer = current_spawn_interval()
	# Элитный враг
	elite_timer -= delta
	if elite_timer <= 0.0:
		spawn_enemy("elite")
		hud.announce(Loc.t("ЭЛИТА!"), Color(1.0, 0.45, 0.4))
		AudioManager.play("chest", -10.0)
		elite_timer = Records.difficulty_value("elite_interval")
	# Мини-босс каждые 2 минуты — «событие» в середине забега
	miniboss_timer -= delta
	if miniboss_timer <= 0.0:
		spawn_miniboss()
		miniboss_timer = 120.0
	# Волна-стая: строй слаймов с одной стороны
	stream_timer -= delta
	if stream_timer <= 0.0:
		spawn_stream_wave()
		stream_timer = 45.0
	# Ловушки арены: обычные каждые 6.5 с, метеоритный дождь раз в 40 с.
	if map_traps:
		trap_timer -= delta
		if trap_timer <= 0.0:
			spawn_hazard()
			trap_timer = 6.5
		shower_timer -= delta
		if shower_timer <= 0.0:
			spawn_meteor_shower()
			shower_timer = 40.0
	# Проверка достижений — раз в секунду, дёшево
	achievement_timer -= delta
	if achievement_timer <= 0.0:
		achievement_timer = 1.0
		check_achievements(false)
	# Кольцевое событие: враги окружают игрока
	event_timer -= delta
	if event_timer <= 0.0:
		spawn_ring_event()
		hud.announce(Loc.t("ВОЛНА: ОКРУЖЕНИЕ!"), Color(1.0, 0.7, 0.3))
		event_timer = 60.0

## Старт спокойный: первая волна через 2 с, потом интервал сокращается.
## Раньше было 1.2 с и разгон быстрее — первая минута превращалась в мясорубку.
# ── Темп забега: интервал и размер волны, потолок врагов, рост HP со временем.
func current_spawn_interval() -> float:
	var base: float = clampf(2.0 - elapsed_time * 0.011, 0.35, 2.0)
	return base * Records.difficulty_value("spawn_interval")

## Размер волны растёт раз в минуту (было — раз в 45 с).
func current_batch_size() -> int:
	var base: int = mini(6, 1 + int(elapsed_time / 60.0))
	return maxi(1, int(round(float(base) * Records.difficulty_value("batch"))))

## Потолок врагов на карте: в начале забега он ниже, к ~1.5 минуте выходит
## на максимум сложности. Так экран не забивается врагами за первую минуту.
func current_enemy_cap() -> int:
	var ramped: int = 20 + int(elapsed_time * 1.4)
	return mini(max_enemies, ramped)

## Рост здоровья врагов со временем. Раньше было +35% за минуту: к 10-й минуте
## враги становились в 4.5 раза толще и убивать их было нечем. Теперь +18%,
## а после 12-й минуты рост замедляется вдвое — толпа остаётся, но не «стены».
const HP_GROWTH_PER_MINUTE: float = 0.18
const HP_GROWTH_SLOWDOWN_AFTER: float = 12.0
const HP_GROWTH_LATE: float = 0.09

func current_hp_multiplier() -> float:
	var minutes: float = elapsed_time / 60.0
	var growth: float = minutes * HP_GROWTH_PER_MINUTE
	if minutes > HP_GROWTH_SLOWDOWN_AFTER:
		growth = HP_GROWTH_SLOWDOWN_AFTER * HP_GROWTH_PER_MINUTE + (minutes - HP_GROWTH_SLOWDOWN_AFTER) * HP_GROWTH_LATE
	return (1.0 + growth) * Records.difficulty_value("enemy_hp")

# ── Обычная волна и лимиты: сколько врагов пускает потолок и сколько пожирателей допустимо.
func spawn_wave() -> void:
	var batch: int = current_batch_size()
	# Лимит врагов: если на экране уже много, новую волну не спавним.
	# Элитный враг спавнится отдельно и лимит не учитывает.
	var alive: int = Enemies.count()
	var allowed: int = maxi(0, current_enemy_cap() - alive)
	var to_spawn: int = mini(batch, allowed)
	for i in range(to_spawn):
		spawn_enemy(pick_enemy_type())

## Пожиратели кристаллов крадут опыт и растут, поэтому их количество на карте
## ограничено. Иначе они копятся, съедают весь опыт и забег превращается в погоню.
const GEM_EATER_LIMIT: int = 2 # Сколько пожирателей может быть одновременно
const GEM_EATER_LIMIT_LATE: int = 3 # Позже — чуть больше
const GEM_EATER_LATE_TIME: float = 420.0 # Когда включается повышенный лимит

## Сколько пожирателей уже создано, но ещё не попало в дерево сцены.
var scheduled_eaters: int = 0

func gem_eater_limit() -> int:
	return GEM_EATER_LIMIT_LATE if elapsed_time >= GEM_EATER_LATE_TIME else GEM_EATER_LIMIT

func gem_eater_count() -> int:
	var count: int = 0
	for enemy in Enemies.all():
		if str(enemy.get("enemy_type")) == "gem_eater":
			count += 1
	return count

## Учитывает и тех, кого уже поставили в очередь на добавление:
## враги добавляются через call_deferred, иначе за один кадр можно
## проскочить лимит несколькими волнами.
func gem_eater_total() -> int:
	return gem_eater_count() + scheduled_eaters

func gem_eater_room() -> bool:
	return gem_eater_total() < gem_eater_limit()

func pick_enemy_type() -> String:
	var roll: float = randf()
	var eaters_full: bool = not gem_eater_room()
	if elapsed_time < 50.0:
		return "slime"
	elif elapsed_time < 110.0:
		if roll < 0.15:
			return "splitter"
		elif roll < 0.45:
			return "bat"
		else:
			return "slime"
	elif elapsed_time < 180.0:
		# С 2-й минуты появляются щитоносцы и бомбардиры — приходится менять тактику.
		if roll < 0.12:
			return "brute"
		elif roll < 0.20:
			return "splitter"
		elif roll < 0.30:
			return "spitter"
		elif roll < 0.42:
			return "shieldbearer"
		elif roll < 0.52:
			return "bomber"
		elif roll < 0.60:
			return "healer"
		elif roll < 0.66:
			# Пожиратели: только пока не упёрлись в лимит, иначе — обычный враг.
			return "bat" if eaters_full else "gem_eater"
		elif roll < 0.85:
			return "bat"
		else:
			return "slime"
	else:
		if roll < 0.14:
			return "brute"
		elif roll < 0.21:
			return "splitter"
		elif roll < 0.33:
			return "spitter"
		elif roll < 0.46:
			return "shieldbearer"
		elif roll < 0.57:
			return "bomber"
		elif roll < 0.65:
			return "healer"
		elif roll < 0.72:
			return "bat" if eaters_full else "gem_eater"
		elif roll < 0.88:
			return "bat"
		else:
			return "slime"

# ── Создание врага: настройка под сложность и отложенное добавление в сцену.
func spawn_enemy(type: String) -> void:
	spawn_enemy_at(type, random_spawn_position())

func spawn_enemy_at(type: String, pos: Vector2) -> void:
	# Страховка: даже прямой вызов не создаст лишнего пожирателя.
	if type == "gem_eater":
		if not gem_eater_room():
			type = "bat"
		else:
			scheduled_eaters += 1
	var enemy = EnemyScene.instantiate()
	var hp_mult: float = current_hp_multiplier()
	if type == "boss":
		hp_mult = Records.difficulty_value("boss_hp") * Records.difficulty_value("enemy_hp")
	enemy.configure(type, hp_mult, pos, Records.difficulty_value("enemy_damage"), Records.difficulty_value("enemy_speed"))
	if type == "gem_eater":
		# Резерв снимаем, когда враг реально оказался в дереве.
		enemy.ready.connect(func() -> void: scheduled_eaters = maxi(0, scheduled_eaters - 1), CONNECT_ONE_SHOT)
	call_deferred("add_child", enemy)

# ── Боссы: финальный на 10-й минуте, мини-боссы каждые 2 минуты и их полоса HP.
func spawn_boss() -> void:
	var angle: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * 600.0
	pos.x = clampf(pos.x, -1500.0, 1500.0)
	pos.y = clampf(pos.y, -1500.0, 1500.0)
	spawn_enemy_at("boss", pos)

func update_boss_bar() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss != null:
		hud.show_boss_bar()
		hud.update_boss_bar(int(boss.get("hp")), int(boss.get("max_hp")))
	else:
		hud.hide_boss_bar()

func spawn_miniboss() -> void:
	var variants: Array = ["mb_slime", "mb_bat", "mb_brute", "mb_spitter"]
	var chosen: String = str(variants[randi() % variants.size()])
	var angle: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * 700.0
	pos.x = clampf(pos.x, -1500.0, 1500.0)
	pos.y = clampf(pos.y, -1500.0, 1500.0)
	spawn_enemy_at(chosen, pos)
	hud.announce(Loc.t("МИНИ-БОСС!"), Color(0.85, 0.5, 1.0))
	AudioManager.play("victory", -14.0)

func update_miniboss_bar() -> void:
	var mb = get_tree().get_first_node_in_group("miniboss")
	if mb != null:
		hud.show_boss_bar()
		hud.set_boss_name(str(mb.get("mini_boss_name")))
		hud.update_boss_bar(int(mb.get("hp")), int(mb.get("max_hp")))
	else:
		hud.hide_boss_bar()

## Отталкивание врагов считается ОДИН раз за кадр по сетке ячеек.
## Раньше каждый враг перебирал всех остальных (60x60), а при 120 врагах
## это 14 400 пар на кадр — игра проседала бы именно там, где врагов больше всего.
# ── Расталкивание врагов: один расчёт на кадр по сетке ячеек вместо перебора всех пар.
const SEPARATION_CELL: float = 48.0

# ── Физика: только расталкивание врагов, раз в кадр.
func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	update_separation()

func update_separation() -> void:
	var enemies: Array = Enemies.all()
	if enemies.is_empty():
		return
	var buckets: Dictionary = {}
	for enemy in enemies:
		if enemy.is_queued_for_deletion():
			continue
		enemy.set("separation_push", Vector2.ZERO)
		var pos: Vector2 = enemy.global_position
		var key: Vector2i = Vector2i(int(floor(pos.x / SEPARATION_CELL)), int(floor(pos.y / SEPARATION_CELL)))
		if buckets.has(key):
			buckets[key].append(enemy)
		else:
			buckets[key] = [enemy]
	for enemy in enemies:
		if enemy.is_queued_for_deletion():
			continue
		var pos: Vector2 = enemy.global_position
		var my_scale: float = float(enemy.get("scale").x)
		var key: Vector2i = Vector2i(int(floor(pos.x / SEPARATION_CELL)), int(floor(pos.y / SEPARATION_CELL)))
		var push: Vector2 = Vector2.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cell_key: Vector2i = key + Vector2i(dx, dy)
				if not buckets.has(cell_key):
					continue
				for other in buckets[cell_key]:
					if other == enemy:
						continue
					var diff: Vector2 = pos - other.global_position
					var dist: float = diff.length()
					var min_dist: float = 16.0 * (my_scale + float(other.get("scale").x)) * 0.9
					if dist > 0.01 and dist < min_dist:
						push += diff / dist * (1.0 - dist / min_dist)
					elif dist <= 0.01:
						var angle: float = float((enemy.get_instance_id() + other.get_instance_id()) % 628) / 100.0
						push += Vector2(cos(angle), sin(angle))
		enemy.set("separation_push", push)

# ── Формации: стая строем с края карты и кольцо врагов вокруг игрока.
func spawn_stream_wave() -> void:
	# Стая идёт строем с одного края — заставляет двигаться, а не стоять в центре.
	var alive: int = Enemies.count()
	var allowed: int = maxi(0, current_enemy_cap() - alive)
	var count: int = mini(16, allowed)
	if count <= 0:
		return
	wave_number += 1
	var side: int = randi() % 4
	for i in range(count):
		var offset: float = (float(i) - float(count) * 0.5) * 70.0
		var pos: Vector2 = player.global_position
		match side:
			0:
				pos += Vector2(-760.0, offset)
			1:
				pos += Vector2(760.0, offset)
			2:
				pos += Vector2(offset, -760.0)
			_:
				pos += Vector2(offset, 760.0)
		pos.x = clampf(pos.x, -1500.0, 1500.0)
		pos.y = clampf(pos.y, -1500.0, 1500.0)
		spawn_enemy_at("slime", pos)
	hud.announce(Loc.t("ВОЛНА: СТАЯ!"), Color(0.6, 1.0, 0.6))

func spawn_ring_event() -> void:
	var alive: int = Enemies.count()
	var allowed: int = maxi(0, current_enemy_cap() - alive)
	var count: int = mini(12, allowed)
	for i in range(count):
		var angle: float = TAU * float(i) / 12.0
		var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * 520.0
		pos.x = clampf(pos.x, -1550.0, 1550.0)
		pos.y = clampf(pos.y, -1550.0, 1550.0)
		spawn_enemy_at("slime", pos)

# ── Точка появления: за пределами экрана, но внутри границ арены.
func random_spawn_position() -> Vector2:
	var angle: float = randf() * TAU
	var distance: float = randf_range(720.0, 860.0)
	var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	pos.x = clampf(pos.x, -1550.0, 1550.0)
	pos.y = clampf(pos.y, -1550.0, 1550.0)
	return pos

# ── Смерть врага: золото, распад сплиттера, «Заморозка», награда за мини-босса и победа за босса.
func on_enemy_killed(enemy) -> void:
	kills += 1
	hud.update_kills(kills)
	# Золото за убийства (мета-валюта).
	var enemy_type: String = str(enemy.get("enemy_type"))
	var gold_reward: int = 1
	if enemy_type == "elite":
		gold_reward = 10
	elif enemy_type == "boss":
		gold_reward = 50
	elif enemy_type.begins_with("mb_"):
		gold_reward = 15
	elif enemy_type == "brute" or enemy_type == "shieldbearer":
		gold_reward = 3
	elif enemy_type == "healer":
		gold_reward = 4
	elif enemy_type == "bomber" or enemy_type == "gem_eater":
		gold_reward = 2
	elif enemy_type == "splitter" or enemy_type == "spitter":
		gold_reward = 2
	gold_reward = maxi(1, int(round(float(gold_reward) * Records.difficulty_value("gold") * map_gold_bonus)))
	Records.add_gold(gold_reward)
	hud.update_gold(Records.gold)
	# Сплиттер распадается на трёх мелких слаймов.
	if str(enemy.get("enemy_type")) == "splitter":
		for i in range(3):
			var angle: float = TAU * float(i) / 3.0
			spawn_enemy_at("slime", enemy.global_position + Vector2(cos(angle), sin(angle)) * 30.0)
	# Эволюция «Заморозка»: замороженный враг разбивается и бьёт соседей.
	if not shatter_active and player != null and float(enemy.get("slow_timer")) > 0.0:
		if player.has_method("has_evo") and bool(player.call("has_evo", "evo_frost")):
			shatter_active = true
			var shatter_damage: int = maxi(1, int(float(player.get("frost_damage")) * 3.0))
			var shatter_radius: float = 110.0
			for other in Enemies.all():
				# Мёртвых и удаляемых не трогаем: урон по ним только шумит.
				if other == enemy or not is_instance_valid(other) or other.is_queued_for_deletion():
					continue
				if bool(other.get("dead")):
					continue
				if enemy.global_position.distance_to(other.global_position) <= shatter_radius:
					other.call("take_damage", shatter_damage, enemy.global_position, "frost")
			FX.burst(enemy.global_position, Color(0.6, 0.9, 1.0), 18, 170.0)
			shatter_active = false
	if bool(enemy.get("is_mini_boss")):
		miniboss_kills += 1
		hud.announce(Loc.t("Мини-босс повержен!"), Color(0.9, 0.9, 0.5))
		hud.hide_boss_bar()
		# Главная награда за мини-босса: ядро эволюции. Оно падает всегда —
		# если готовых эволюций нет, ядро даст обычный выбор улучшения.
		spawn_evo_core(enemy.global_position)
	# Босс убит — только теперь Победа.
	if str(enemy.get("enemy_type")) == "boss":
		hud.hide_boss_bar()
		RunStats.boss_killed_at = elapsed_time
		trigger_victory()

# ── Ядро эволюции: падает с мини-босса, при подборе — пауза и выбор награды.
func spawn_evo_core(at_position: Vector2) -> void:
	var core = EvoCoreScene.instantiate()
	core.configure(at_position)
	add_child(core)
	hud.announce(Loc.t("Ядро эволюции! Подбери его"), Color(1.0, 0.8, 0.35), 22)

## Ядро подобрано: пауза и выбор. Есть готовые эволюции — показываем их,
## иначе даём обычное улучшение, чтобы награда за мини-босса не была пустой.
func on_evo_core_collected() -> void:
	if game_over:
		return
	var evolutions: Array = player.call("get_evolution_choices", 3)
	get_tree().paused = true
	if not evolutions.is_empty():
		evo_reward_pending = true
		hud.show_level_up(evolutions, "Ядро эволюции! Выбери эволюцию:")
	else:
		core_reward_pending = true
		hud.show_level_up(player.call("get_upgrade_choices", 3), "Ядро мини-босса: выбери награду:")
	hud.update_reroll_cost(reroll_cost(), Records.gold)

# ── Ловушки арены: метеорит или шипы рядом с игроком плюс метеоритный дождь.
func spawn_hazard() -> void:
	# Ловушка появляется рядом с игроком: от неё нужно уходить, но и толпу она бьёт.
	var angle: float = randf() * TAU
	var distance: float = randf_range(110.0, 300.0)
	var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	pos.x = clampf(pos.x, -1520.0, 1520.0)
	pos.y = clampf(pos.y, -1520.0, 1520.0)
	var hazard = HazardScene.instantiate()
	if randf() < 0.6:
		hazard.configure("meteor", 110.0, 25, 60, 0.9) # телеграф 0.9 с — успеваешь выйти
	else:
		hazard.configure("spikes", 85.0, 6, 16, 0.55)
	hazard.position = pos
	add_child(hazard)

func spawn_meteor_shower() -> void:
	hud.announce(Loc.t("МЕТЕОРИТНЫЙ ДОЖДЬ!"), Color(1.0, 0.55, 0.25), 28)
	AudioManager.play("explosion", -10.0)
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + randf() * 0.4
		var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * randf_range(150.0, 340.0)
		pos.x = clampf(pos.x, -1520.0, 1520.0)
		pos.y = clampf(pos.y, -1520.0, 1520.0)
		var hazard = HazardScene.instantiate()
		hazard.configure("meteor", randf_range(95.0, 130.0), 25, 60, 1.3)
		hazard.position = pos
		add_child(hazard)

# ── Карта: цвет фона и декора, ловушки, бонус золота, зоны трясины.
func apply_map() -> void:
	# Оформление арены под выбранную карту + её особые объекты.
	var map_data: Dictionary = Records.get_map()
	var background: Polygon2D = get_node_or_null("Background")
	if background != null:
		background.color = map_data["background"]
	for i in range(1, 6):
		var decor = get_node_or_null("Decor%d" % i)
		if decor != null:
			decor.color = map_data["decor"]
	map_traps = bool(map_data.get("traps", false))
	map_gold_bonus = float(map_data.get("gold_bonus", 1.0))
	max_enemies += int(map_data.get("enemy_cap_bonus", 0))
	var zone_count: int = int(map_data.get("slow_zones", 0))
	if zone_count > 0:
		spawn_slow_zones(zone_count)
		hud.announce(Loc.t(str(map_data["name"])).to_upper() + "!", Color(0.6, 0.95, 0.6), 30)
	elif map_traps:
		hud.announce(Loc.t(str(map_data["name"])).to_upper() + "!", Color(1.0, 0.6, 0.4), 30)

# ── Зоны трясины: раскладка фиксированным сидом, чтобы карта была одинаковой в каждом забеге.
func spawn_slow_zones(count: int) -> void:
	# Раскладываем зоны фиксированным сидом: карта одинаковая в каждом забеге.
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
		add_child(zone)
		slow_zones.append(zone)

# ── Итоги и достижения: сводка забега и проверка достижений с наградой.
func build_run_data(victory: bool) -> Dictionary:
	return {
		"kills": kills,
		"level": int(player.get("level")),
		"time": elapsed_time,
		"damage_taken": int(player.get("damage_taken")),
		"evolutions": player.get("evolutions").size(),
		"spells": player.get("unlocked_weapons").size(),
		"spell_ids": player.get("unlocked_weapons"),
		"miniboss_kills": miniboss_kills,
		"victory": victory,
		"difficulty": Records.selected_difficulty,
	}

func check_achievements(victory: bool) -> void:
	var newly: Array = Records.check_run_achievements(build_run_data(victory))
	if newly.is_empty():
		return
	for entry in newly:
		AudioManager.play("chest", -6.0)
		hud.announce(Loc.t("ДОСТИЖЕНИЕ: %s  +%d золота") % [Loc.t(str(entry["name"])), int(entry["gold"])], Color(1.0, 0.9, 0.35), 22)
	hud.update_gold(Records.gold)

# ── Переброс: цена растёт с каждым использованием, новый набор того же типа выбора.
func reroll_cost() -> int:
	# Первый реролл дешёвый, дальше дорожает — чтобы не спамили.
	return 10 + reroll_count * 5

func _on_reroll_requested() -> void:
	if game_over or victory_shown:
		return
	var cost: int = reroll_cost()
	if Records.gold < cost:
		AudioManager.play("hit", -16.0)
		hud.set_reroll_hint("Не хватает золота")
		return
	Records.add_gold(-cost)
	hud.update_gold(Records.gold)
	reroll_count += 1
	AudioManager.play("gem", -8.0)
	# Показываем новый набор того же типа выбора.
	if hud.choosing_spell:
		hud.show_spell_choices(player.call("get_spell_choices"))
	elif hud.choosing_level5:
		# Переброс меняет и заклинания, и то, у какого заклинания поднимется урон.
		hud.show_level5_choices(player.call("get_level5_choices"))
	elif evo_reward_pending:
		hud.show_level_up(player.call("get_evolution_choices", 3), "Ядро эволюции! Выбери эволюцию:")
	elif core_reward_pending:
		hud.show_level_up(player.call("get_upgrade_choices", 3), "Ядро мини-босса: выбери награду:")
	elif chest_reward_pending:
		hud.show_level_up(player.call("get_upgrade_choices", 3), "Сундук! Выбери награду:")
	else:
		hud.show_level_up(player.call("get_upgrade_choices", 3))
	hud.update_reroll_cost(reroll_cost(), Records.gold)

# ── Прокачка: пауза и очередь выборов — заклинание, улучшение, сундук, ядро.
func _on_player_leveled_up() -> void:
	AudioManager.play("levelup", -4.0)
	FX.burst(player.global_position, Color(1.0, 0.85, 0.2), 24, 160.0)
	get_tree().paused = true
	show_next_choice()

func show_next_choice() -> void:
	# Порядок: сначала новое заклинание (каждый 5-й уровень), потом улучшение.
	if int(player.get("pending_spell_choices")) > 0:
		# Пятый уровень: один выбор — два заклинания и «+50% урона» по центру.
		var lvl5: Array = player.call("get_level5_choices")
		# Пустое окно выбора держало бы игру на паузе.
		if lvl5.is_empty():
			player.set("pending_spell_choices", 0)
		else:
			hud.show_level5_choices(lvl5)
			hud.update_reroll_cost(reroll_cost(), Records.gold)
			return
	if int(player.get("pending_level_ups")) > 0:
		hud.show_level_up(player.call("get_upgrade_choices", 3))
	else:
		hud.hide_level_up()
		get_tree().paused = false
		return
	hud.update_reroll_cost(reroll_cost(), Records.gold)

func on_chest_opened() -> void:
	if game_over:
		return
	AudioManager.play("chest", -4.0)
	chest_reward_pending = true
	get_tree().paused = true
	hud.show_level_up(player.call("get_upgrade_choices", 3), "Сундук! Выбери награду:")
	hud.update_reroll_cost(reroll_cost(), Records.gold)

## Усиление урона из панели 5-го уровня: уровень уже израсходован на этот выбор.
func _on_level5_chosen(card_id: String) -> void:
	player.call("apply_upgrade", card_id)
	player.set("pending_spell_choices", maxi(0, int(player.get("pending_spell_choices")) - 1))
	show_next_choice()

func _on_spell_chosen(spell_id: String) -> void:
	player.call("unlock_spell", spell_id)
	player.set("pending_spell_choices", int(player.get("pending_spell_choices")) - 1)
	show_next_choice()

func _on_upgrade_chosen(upgrade_id: String) -> void:
	player.call("apply_upgrade", upgrade_id)
	if upgrade_id.begins_with("evo_"):
		var evo_name: String = str(player.get("evolution_names").get(upgrade_id, "Эволюция"))
		hud.announce(Loc.t("ЭВОЛЮЦИЯ: %s!") % Loc.t(evo_name), Color(1.0, 0.85, 0.25))
		hud.update_gold(Records.gold)
	# Выбор за ядро мини-босса не тратит уровень и не считается сундуком.
	if evo_reward_pending:
		evo_reward_pending = false
		show_next_choice()
		return
	if core_reward_pending:
		core_reward_pending = false
		show_next_choice()
		return
	# Выбор из сундука не тратит уровень.
	if chest_reward_pending:
		chest_reward_pending = false
		show_next_choice()
		return
	player.set("pending_level_ups", int(player.get("pending_level_ups")) - 1)
	show_next_choice()

# ── Финал забега: победа, выход в бесконечный режим, поражение, рестарт и выход в меню.
func trigger_victory() -> void:
	victory_shown = true
	AudioManager.play("victory", -2.0)
	AudioManager.stop_music(1.2)
	FX.shake(0.9, 1.4)
	FX.flash(Color(1.0, 0.9, 0.4), 0.35, 0.8)
	Records.add_gold(100) # Бонус за победу над боссом
	hud.update_gold(Records.gold)
	if not run_finished:
		run_finished = true
		Records.finish_run(elapsed_time, kills, int(player.get("level")), true)
	check_achievements(true)
	hud.show_victory(elapsed_time, kills, int(player.get("level")))
	get_tree().paused = true

func _on_continue_endless() -> void:
	hud.hide_victory()
	get_tree().paused = false

func _on_victory_menu() -> void:
	# Победоносный забег сохраняем в рекорды при выходе в меню.
	Records.save_run(elapsed_time, kills, int(player.get("level")))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if not run_finished:
		run_finished = true
		Records.finish_run(elapsed_time, kills, int(player.get("level")), false)
	check_achievements(false)
	AudioManager.play("gameover", -2.0)
	AudioManager.stop_music(1.5)
	FX.shake(1.0, 1.2)
	FX.flash(Color(0.6, 0.0, 0.0), 0.4, 0.9)
	# Сохраняем забег в рекорды (автозагрузка Records)
	var is_new_record: bool = Records.save_run(elapsed_time, kills, int(player.get("level")))
	hud.show_game_over(elapsed_time, kills, int(player.get("level")), is_new_record)
	get_tree().paused = true

func _on_restart_requested() -> void:
	# Выход из забега без смерти тоже учитываем в профиле.
	if not run_finished:
		run_finished = true
		check_achievements(false)
		Records.finish_run(elapsed_time, kills, int(player.get("level")), false)
		Records.save_run(elapsed_time, kills, int(player.get("level")))
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_requested() -> void:
	if not run_finished:
		run_finished = true
		check_achievements(false)
		Records.finish_run(elapsed_time, kills, int(player.get("level")), false)
		Records.save_run(elapsed_time, kills, int(player.get("level")))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
