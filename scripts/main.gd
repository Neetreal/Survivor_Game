extends Node2D
## Главная сцена: связка забега — таймер, спавн (`spawner`), карта (`arena`),
## награды и итоги (`flow`), расталкивание врагов и смерть врага.
## Main работает в режиме ALWAYS, чтобы принимать сигналы меню во время паузы,
## а внутри _process сам проверяет get_tree().paused.

# ── Состояние забега, которое видят модули и враги (через группу "game").
var elapsed_time: float = 0.0
var kills: int = 0
var max_enemies: int = 60 # Лимит врагов на экране — защита от лагов (зависит от сложности)
var game_over: bool = false
var victory_shown: bool = false
## Защита от рекурсии: замороженный враг разбивается один раз за кадр.
var shatter_active: bool = false

# ── Узлы сцены: игрок, интерфейс и три модуля забега.
@onready var player = $Player
@onready var hud = $HUD
@onready var spawner: RunSpawner = $Spawner
@onready var arena: RunArena = $Arena
@onready var flow: RunFlow = $Flow

# ── Старт забега: модули, сложность, музыка, профиль, подписка на сигналы игрока и HUD.
func _ready() -> void:
	# Модули получают ссылку на забег: через неё берут игрока, HUD и время.
	spawner.m = self
	arena.m = self
	flow.m = self
	# Лимит врагов и таймеры — под выбранную сложность.
	spawner.apply_difficulty()
	Enemies.clear() # реестр врагов: начинаем забег с чистого листа
	AudioManager.play_music("battle")
	Records.start_run() # профиль: счётчик забегов и героев
	RunStats.reset() # экран результатов: урон по источникам и золото за забег
	arena.apply_map()
	player.connect("died", flow.on_player_died)
	player.connect("leveled_up", flow.on_leveled_up)
	hud.connect("upgrade_chosen", flow.on_upgrade_chosen)
	hud.connect("restart_requested", flow.on_restart_requested)
	hud.connect("menu_requested", flow.on_menu_requested)
	hud.connect("spell_chosen", flow.on_spell_chosen)
	hud.connect("level5_chosen", flow.on_level5_chosen)
	hud.connect("continue_endless_requested", flow.on_continue_endless)
	hud.connect("victory_menu_requested", flow.on_victory_menu)
	hud.connect("reroll_requested", flow.on_reroll_requested)
	hud.update_kills(0)
	hud.update_timer(0.0)

# ── Кадр забега: таймер, спавн врагов, карта и проверка достижений.
func _process(delta: float) -> void:
	if game_over or get_tree().paused:
		return
	elapsed_time += delta
	hud.update_timer(elapsed_time)
	spawner.tick(delta)
	arena.tick(delta)
	flow.tick(delta)

# ── Физика: только расталкивание врагов, раз в кадр.
func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	update_separation()

## Отталкивание врагов считается ОДИН раз за кадр по сетке ячеек.
## Раньше каждый враг перебирал всех остальных (60x60), а при 120 врагах
## это 14 400 пар на кадр — игра проседала бы именно там, где врагов больше всего.
# ── Расталкивание врагов: один расчёт на кадр по сетке ячеек вместо перебора всех пар.
const SEPARATION_CELL: float = 48.0

func update_separation() -> void:
	var enemies: Array = Enemies.all()
	if enemies.is_empty():
		return
	# LOD: расталкиваем только видимых — враги за экраном идут по прямой к игроку.
	# Вектор всё равно обнуляем, иначе у вернувшегося на экран врага остался бы старый толчок.
	var buckets: Dictionary = {}
	var visible: Array = []
	for enemy in enemies:
		if enemy.is_queued_for_deletion():
			continue
		enemy.set("separation_push", Vector2.ZERO)
		# Сравнение именно с false: если поле вдруг не найдётся, врага оставляем в сетке.
		if enemy.get("on_screen") == false:
			continue
		visible.append(enemy)
		var pos: Vector2 = enemy.global_position
		var key: Vector2i = Vector2i(int(floor(pos.x / SEPARATION_CELL)), int(floor(pos.y / SEPARATION_CELL)))
		if buckets.has(key):
			buckets[key].append(enemy)
		else:
			buckets[key] = [enemy]
	if visible.is_empty():
		return
	for enemy in visible:
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
	gold_reward = maxi(1, int(round(float(gold_reward) * Records.difficulty_value("gold") * arena.map_gold_bonus)))
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
		flow.miniboss_kills += 1
		hud.announce(Loc.t("Мини-босс повержен!"), Color(0.9, 0.9, 0.5))
		hud.hide_boss_bar()
		# Главная награда за мини-босса: ядро эволюции. Оно падает всегда —
		# если готовых эволюций нет, ядро даст обычный выбор улучшения.
		flow.spawn_evo_core(enemy.global_position)
	# Босс убит — только теперь Победа.
	if str(enemy.get("enemy_type")) == "boss":
		hud.hide_boss_bar()
		RunStats.boss_killed_at = elapsed_time
		flow.trigger_victory()

# ── Что зовут извне (группа "game"): враги, сундуки и ядра — через главную сцену.
func spawn_enemy_at(type: String, pos: Vector2) -> void:
	spawner.spawn_enemy_at(type, pos)

func on_chest_opened() -> void:
	flow.on_chest_opened()

func on_evo_core_collected() -> void:
	flow.on_evo_core_collected()
