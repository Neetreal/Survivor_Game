class_name RunSpawner
extends Node
## Спавн врагов: темп забега, виды врагов, волны, босс и мини-боссы.

# ── Ссылка на забег (main.gd): через неё берём игрока, HUD, время и лимит врагов.
var m

## События-формации («стая» и «окружение»). Раньше это были фиксированные 16 и 12
## врагов каждые 45/60 с — на первой минуте экран заваливало толпой, которую
## нечем было пробить. Теперь событие начинается с 3 врагов и растёт на одного
## за каждую минуту забега, а между событиями — по 2 минуты (первое на 1:30).
const EVENT_BASE_COUNT: int = 3 # Сколько врагов в самом первом событии
const EVENT_COUNT_PER_MINUTE: float = 1.0 # Прирост врагов за минуту забега
const EVENT_COUNT_MAX: int = 12 # Потолок события (дальше растёт обычный спавн)
const EVENT_FIRST_STREAM: float = 90.0 # Первая «стая» — 1:30
const EVENT_FIRST_RING: float = 150.0 # Первое «окружение» — 2:30
const EVENT_INTERVAL: float = 120.0 # Между событиями одного типа — 2 минуты

# ── Состояние спавна: свои таймеры, номер волны и флаг появления босса.
var spawn_timer: float = 2.0
var elite_timer: float = 75.0
var event_timer: float = EVENT_FIRST_RING # Кольцевое событие («окружение»)
var miniboss_timer: float = 120.0
var stream_timer: float = EVENT_FIRST_STREAM # Стая строем
var wave_number: int = 0
var boss_spawned: bool = false
## Сколько пожирателей уже создано, но ещё не попало в дерево сцены.
var scheduled_eaters: int = 0

# ── Сцены и константы темпа: враг грузится один раз, рост HP задан здесь.
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")

## Рост здоровья врагов со временем. Раньше было +35% за минуту: к 10-й минуте
## враги становились в 4.5 раза толще и убивать их было нечем. Теперь +18%,
## а после 12-й минуты рост замедляется вдвое — толпа остаётся, но не «стены».
const HP_GROWTH_PER_MINUTE: float = 0.18
const HP_GROWTH_SLOWDOWN_AFTER: float = 12.0
const HP_GROWTH_LATE: float = 0.09

## Пожиратели кристаллов крадут опыт и растут, поэтому их количество на карте
## ограничено. Иначе они копятся, съедают весь опыт и забег превращается в погоню.
const GEM_EATER_LIMIT: int = 2 # Сколько пожирателей может быть одновременно
const GEM_EATER_LIMIT_LATE: int = 3 # Позже — чуть больше
const GEM_EATER_LATE_TIME: float = 420.0 # Когда включается повышенный лимит

# ── Старт забега: лимит врагов и интервал элиты под выбранную сложность.
func apply_difficulty() -> void:
	m.max_enemies = int(Records.difficulty_value("enemy_cap"))
	elite_timer = Records.difficulty_value("elite_interval")

# ── Кадр спавна: босс, полосы HP и всё расписание волн.
func tick(delta: float) -> void:
	_tick_boss()
	_update_bars()
	_tick_spawn(delta)

# ── Босс на 10-й минуте: Победа только после его смерти.
func _tick_boss() -> void:
	if boss_spawned or m.elapsed_time < 600.0:
		return
	boss_spawned = true
	RunStats.boss_spawn_time = m.elapsed_time
	spawn_boss()
	AudioManager.play_music("boss")
	FX.shake(0.8, 1.5)
	FX.flash(Color(0.8, 0.05, 0.1), 0.25, 0.6)
	m.hud.set_boss_name("БОСС")
	m.hud.announce(Loc.t("БОСС!"), Color(1.0, 0.25, 0.3))

# ── Полоса HP: у босса приоритет, иначе показываем мини-босса.
func _update_bars() -> void:
	if boss_spawned and not m.victory_shown:
		update_boss_bar()
	elif not m.victory_shown:
		update_miniboss_bar()

# ── Расписание спавна: у каждого события свой таймер (волна, элита, мини-босс, стая, окружение).
func _tick_spawn(delta: float) -> void:
	# Обычный спавн
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_wave()
		spawn_timer = current_spawn_interval()
	# Элитный враг
	elite_timer -= delta
	if elite_timer <= 0.0:
		spawn_enemy("elite")
		m.hud.announce(Loc.t("ЭЛИТА!"), Color(1.0, 0.45, 0.4))
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
		stream_timer = EVENT_INTERVAL
	# Кольцевое событие: враги окружают игрока
	event_timer -= delta
	if event_timer <= 0.0:
		# Объявляем, только если враги реально появились (потолок мог не пустить).
		if spawn_ring_event() > 0:
			m.hud.announce(Loc.t("ВОЛНА: ОКРУЖЕНИЕ!"), Color(1.0, 0.7, 0.3))
		event_timer = EVENT_INTERVAL

# ── Темп забега: интервал и размер волны, потолок врагов, рост HP со временем.
## Старт спокойный: первая волна через 2 с, потом интервал сокращается.
## Раньше было 1.2 с и разгон быстрее — первая минута превращалась в мясорубку.
func current_spawn_interval() -> float:
	var base: float = clampf(2.0 - m.elapsed_time * 0.011, 0.35, 2.0)
	return base * Records.difficulty_value("spawn_interval")

## Размер волны растёт раз в минуту (было — раз в 45 с).
func current_batch_size() -> int:
	var base: int = mini(6, 1 + int(m.elapsed_time / 60.0))
	return maxi(1, int(round(float(base) * Records.difficulty_value("batch"))))

## Сколько врагов в событии-формации: 3 в начале, +1 за каждую минуту забега,
## потолок EVENT_COUNT_MAX. На 9-й минуте события выходят на максимум.
func current_event_count() -> int:
	var grown: int = EVENT_BASE_COUNT + int(m.elapsed_time / 60.0 * EVENT_COUNT_PER_MINUTE)
	return clampi(grown, EVENT_BASE_COUNT, EVENT_COUNT_MAX)

## Потолок врагов на карте: в начале забега он ниже, к ~1.5 минуте выходит
## на максимум сложности. Так экран не забивается врагами за первую минуту.
func current_enemy_cap() -> int:
	var ramped: int = 20 + int(m.elapsed_time * 1.4)
	return mini(m.max_enemies, ramped)

func current_hp_multiplier() -> float:
	var minutes: float = m.elapsed_time / 60.0
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

func gem_eater_limit() -> int:
	return GEM_EATER_LIMIT_LATE if m.elapsed_time >= GEM_EATER_LATE_TIME else GEM_EATER_LIMIT

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
	if m.elapsed_time < 50.0:
		return "slime"
	elif m.elapsed_time < 110.0:
		if roll < 0.15:
			return "splitter"
		elif roll < 0.45:
			return "bat"
		else:
			return "slime"
	elif m.elapsed_time < 180.0:
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
	# Враги живут в главной сцене, как и раньше: так сохраняется порядок отрисовки.
	m.call_deferred("add_child", enemy)

# ── Боссы: финальный на 10-й минуте, мини-боссы каждые 2 минуты и их полоса HP.
func spawn_boss() -> void:
	var angle: float = randf() * TAU
	var pos: Vector2 = m.player.global_position + Vector2(cos(angle), sin(angle)) * 600.0
	pos.x = clampf(pos.x, -1500.0, 1500.0)
	pos.y = clampf(pos.y, -1500.0, 1500.0)
	spawn_enemy_at("boss", pos)

func update_boss_bar() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss != null:
		m.hud.show_boss_bar()
		m.hud.update_boss_bar(int(boss.get("hp")), int(boss.get("max_hp")))
	else:
		m.hud.hide_boss_bar()

func spawn_miniboss() -> void:
	var variants: Array = ["mb_slime", "mb_bat", "mb_brute", "mb_spitter"]
	var chosen: String = str(variants[randi() % variants.size()])
	var angle: float = randf() * TAU
	var pos: Vector2 = m.player.global_position + Vector2(cos(angle), sin(angle)) * 700.0
	pos.x = clampf(pos.x, -1500.0, 1500.0)
	pos.y = clampf(pos.y, -1500.0, 1500.0)
	spawn_enemy_at(chosen, pos)
	m.hud.announce(Loc.t("МИНИ-БОСС!"), Color(0.85, 0.5, 1.0))
	AudioManager.play("victory", -14.0)

func update_miniboss_bar() -> void:
	var mb = get_tree().get_first_node_in_group("miniboss")
	if mb != null:
		m.hud.show_boss_bar()
		m.hud.set_boss_name(str(mb.get("mini_boss_name")))
		m.hud.update_boss_bar(int(mb.get("hp")), int(mb.get("max_hp")))
	else:
		m.hud.hide_boss_bar()

# ── Формации: стая строем с края карты и кольцо врагов вокруг игрока.
func spawn_stream_wave() -> void:
	# Стая идёт строем с одного края — заставляет двигаться, а не стоять в центре.
	var alive: int = Enemies.count()
	var allowed: int = maxi(0, current_enemy_cap() - alive)
	var count: int = mini(current_event_count(), allowed)
	if count <= 0:
		return
	wave_number += 1
	var side: int = randi() % 4
	for i in range(count):
		var offset: float = (float(i) - float(count) * 0.5) * 70.0
		var pos: Vector2 = m.player.global_position
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
	m.hud.announce(Loc.t("ВОЛНА: СТАЯ!"), Color(0.6, 1.0, 0.6))

## Возвращает, сколько врагов реально выставило кольцо.
func spawn_ring_event() -> int:
	var alive: int = Enemies.count()
	var allowed: int = maxi(0, current_enemy_cap() - alive)
	var count: int = mini(current_event_count(), allowed)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var pos: Vector2 = m.player.global_position + Vector2(cos(angle), sin(angle)) * 520.0
		pos.x = clampf(pos.x, -1550.0, 1550.0)
		pos.y = clampf(pos.y, -1550.0, 1550.0)
		spawn_enemy_at("slime", pos)
	return count

# ── Точка появления: за пределами экрана, но внутри границ арены.
func random_spawn_position() -> Vector2:
	var angle: float = randf() * TAU
	var distance: float = randf_range(720.0, 860.0)
	var pos: Vector2 = m.player.global_position + Vector2(cos(angle), sin(angle)) * distance
	pos.x = clampf(pos.x, -1550.0, 1550.0)
	pos.y = clampf(pos.y, -1550.0, 1550.0)
	return pos
