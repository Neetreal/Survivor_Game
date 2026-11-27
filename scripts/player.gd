extends CharacterBody2D
## Игрок-выживальщик: движение WASD, авто-оружие, опыт и улучшения.

# ── Сигналы: HUD и Main подписываются на изменения вместо опроса каждый кадр.
signal hp_changed(current_hp: int, maximum_hp: int)
signal xp_changed(current_xp: int, xp_next: int, level: int)
signal leveled_up
signal died
signal stats_changed


# ── Статы героя: база из Records, дальше их меняют улучшения и магазин.
# Характеристики (меняются улучшениями)
var max_hp: int = 100
var hp: int = 100
var speed: float = 230.0
var armor: int = 0
var magnet_radius: float = 95.0
var xp_multiplier: float = 1.0

# ── Статы заклинаний: своя группа переменных у каждого, имена собраны в WEAPON_DAMAGE_VARS.
var bolt_damage: int = 12
var bolt_cooldown: float = 0.9
var bolt_count: int = 1
var bolt_speed: float = 540.0
var bolt_range: float = 420.0 # Дальность: дальше этого радиуса игрок не стреляет
var bolt_pierce: int = 1 # Сколько врагов пробивает снаряд (999 = без предела, эволюция «Залп»)
var bolt_ricochet: int = 0 # Отскоков после попадания (карта «Рикошет», максимум 2)
var bolt_homing: float = 0.0 # Скорость доворота на цель, рад/с (0 = снаряд летит прямо)

var orbit_damage: int = 10
var orbit_blade_count: int = 1
var orbit_rotation_speed: float = 2.4
var orbit_blade_size: float = 1.0 # Множитель размера клинков (улучшение)

var nova_damage: int = 15
var nova_radius: float = 140.0
var nova_cooldown: float = 2.5

var chain_damage: int = 18
var chain_cooldown: float = 1.8
var chain_range: float = 320.0 # Дальность первой цели от игрока
var chain_jump_range: float = 180.0 # Дальность перескока между врагами
var chain_jumps: int = 3 # Сколько врагов после первого

var fire_damage: int = 20
var fire_cooldown: float = 1.4
var fire_count: int = 1
var fire_radius: float = 75.0 # Радиус взрыва

var frost_damage: int = 3 # Урон за тик (каждые 0.5 сек)
var frost_radius: float = 130.0
var frost_slow: float = 0.5 # Множитель скорости врагов (0.5 = вдвое медленнее)

# Копьё — пробивающий выстрел по прямой
var spear_damage: int = 26
var spear_cooldown: float = 2.0
var spear_count: int = 1
var spear_range: float = 520.0
var spear_speed: float = 640.0

# Мина — ловушка под ноги, взрывается при касании
var mine_damage: int = 40
var mine_cooldown: float = 3.0
var mine_count: int = 1
var mine_radius: float = 110.0

# Ядовитое облако — зона урона на земле
var poison_damage: int = 5
var poison_cooldown: float = 2.6
var poison_radius: float = 115.0
var poison_duration: float = 4.0

# Пила — кружит по большой окружности
var saw_damage: int = 12
var saw_cooldown: float = 2.4
var saw_count: int = 1
var saw_radius: float = 190.0

var boom_damage: int = 14

## Переменная урона у каждого заклинания — нужна для карточки «+50% урона одному заклинанию».

# ── Таблица «id заклинания → переменная урона»: нужна карточкам «+50% урону».
const WEAPON_DAMAGE_VARS := {
	"bolt": "bolt_damage",
	"orbit": "orbit_damage",
	"nova": "nova_damage",
	"chain": "chain_damage",
	"fireball": "fire_damage",
	"frost": "frost_damage",
	"boomerang": "boom_damage",
	"spear": "spear_damage",
	"mine": "mine_damage",
	"poison": "poison_damage",
	"saw": "saw_damage",
}
## Прибавка урона за карточку 5-го уровня.
const LEVEL5_DAMAGE_BONUS: float = 1.5
var boom_cooldown: float = 1.6
var boom_count: int = 1
var boom_range: float = 210.0 # Дальность вылета бумеранга

# ── Прогресс забега: опыт, уровень, отложенные выборы улучшений, флаги смерти.
var xp: int = 0
var level: int = 1
var xp_next: int = 5
var pending_level_ups: int = 0
var pending_spell_choices: int = 0
var character_id: String = "mage"
var unlocked_weapons: Array = [] # id заклинаний: bolt / orbit / nova / chain
var dead: bool = false
var damage_taken: int = 0 # Сколько всего урона получено за забег (для достижений)
var zone_slow: float = 1.0 # Множитель скорости от зон трясины (1.0 = без замедления)

# ── Пассивные предметы: уровни 0..5, бонусы применяются через _apply_stat_upgrade.
# ---------------- Пассивные предметы ----------------
# Уровни пассивок: 0..5. Каждый уровень даёт небольшой постоянный бонус.
var passive_levels: Dictionary = {"book": 0, "candle": 0, "glove": 0, "boots": 0, "heart": 0, "magnet": 0}
var passive_definitions: Array = PassiveData.LIST

var damage_mult: float = 1.0 # Множитель урона (перчатка)
var area_mult: float = 1.0 # Множитель площади/дальности (свеча)

# ── Эволюции оружия: id разблокированных и их имена для отчёта.
# ---------------- Эволюции оружия ----------------
var evolutions: Array = []
var evolution_names: Dictionary = WeaponData.evolution_names()

# ── Таймер вспышки урона (таймеры оружия живут в player_weapons.gd).
var flash_timer: float = 0.0

# ── Узлы сцены: спрайт (или фолбэк-кружок), орбита клинков, аура льда.
@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body
@onready var orbit_pivot: Node2D = $OrbitPivot
@onready var frost_visual: Polygon2D = $FrostVisual
@onready var weapons: PlayerWeapons = $Weapons

# ── Старт забега: применить героя и магазин, посчитать опыт, собрать клинки.
func _ready() -> void:
	# ВАЖНО: Main стоит в режиме ALWAYS, а дети наследуют режим родителя.
	# Поэтому явно ставим PAUSABLE, иначе игрок не остановится на паузе прокачки.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	apply_character(Records.get_character(Records.selected_character))
	apply_meta_upgrades()
	xp_next = xp_needed_for_level(level)
	weapons.p = self # модуль оружия читает статы игрока через эту ссылку
	weapons.rebuild_orbit_blades()
	hp_changed.emit(hp, max_hp)
	xp_changed.emit(xp, xp_next, level)
	stats_changed.emit()

func apply_character(char_data: Dictionary) -> void:
	character_id = str(char_data["id"])
	max_hp = int(char_data["max_hp"])
	hp = max_hp
	speed = float(char_data["speed"])
	armor = int(char_data["armor"])
	magnet_radius = float(char_data["magnet"])
	apply_body_sprite(char_data["color"])
	unlocked_weapons = [str(char_data["spell"])]

## Спрайт героя по id. Нет файла — остаётся старый цветной кружок (фолбэк).
func apply_body_sprite(fallback_color: Color) -> void:
	var path: String = "res://art/sprites/hero_%s.png" % character_id
	if ResourceLoader.exists(path):
		body.texture = load(path)
		body.visible = true
		visual.visible = false
		_load_walk_frames()
	else:
		body.visible = false
		visual.visible = true
		visual.color = fallback_color

# ── Походка: покадровые спрайты, если они есть; иначе процедурная анимация.
## Покадровая походка: если рядом с базовым спрайтом лежат <id>_walk1 и <id>_walk2,
## собираем цикл «стойка → шаг → стойка → шаг другой ногой». Нет кадров —
## остаётся процедурная анимация ниже.
var walk_frames: Array = []
var _frame_time: float = 0.0
var _frame_index: int = 0
const WALK_FPS: float = 10.0

func _load_walk_frames() -> void:
	walk_frames.clear()
	_frame_index = 0
	_frame_time = 0.0
	var first: String = "res://art/sprites/hero_%s_walk1.png" % character_id
	var second: String = "res://art/sprites/hero_%s_walk2.png" % character_id
	if ResourceLoader.exists(first) and ResourceLoader.exists(second):
		walk_frames = [body.texture, load(first), body.texture, load(second)]

## Вспышка урона и прочие тинты идут в оба слоя: видимый сейчас и запасной.
func set_body_modulate(color: Color) -> void:
	visual.modulate = color
	body.modulate = color

func apply_meta_upgrades() -> void:
	# Постоянные улучшения из магазина (сохраняются между забегами).
	var vitality: int = int(Records.meta_upgrades.get("vitality", 0))
	var power: int = int(Records.meta_upgrades.get("power", 0))
	var swift: int = int(Records.meta_upgrades.get("swift", 0))
	var guard: int = int(Records.meta_upgrades.get("guard", 0))
	var magnet: int = int(Records.meta_upgrades.get("magnet", 0))
	var wisdom: int = int(Records.meta_upgrades.get("wisdom", 0))
	max_hp += vitality * 10
	hp = max_hp
	speed *= 1.0 + float(swift) * 0.02
	armor += guard
	magnet_radius += float(magnet) * 15.0
	xp_multiplier += float(wisdom) * 0.03
	var power_mult: float = 1.0 + float(power) * 0.05
	bolt_damage = int(float(bolt_damage) * power_mult)
	orbit_damage = int(float(orbit_damage) * power_mult)
	nova_damage = int(float(nova_damage) * power_mult)
	chain_damage = int(float(chain_damage) * power_mult)
	fire_damage = int(float(fire_damage) * power_mult)
	frost_damage = int(float(frost_damage) * power_mult)
	boom_damage = int(float(boom_damage) * power_mult)
	spear_damage = int(float(spear_damage) * power_mult)
	mine_damage = int(float(mine_damage) * power_mult)
	poison_damage = int(float(poison_damage) * power_mult)
	saw_damage = int(float(saw_damage) * power_mult)

# ── Главный цикл: движение, походка, таймеры всех заклинаний, затухание вспышки.
func _physics_process(delta: float) -> void:
	if dead:
		return
	# Движение
	var input_dir: Vector2 = get_input_vector()
	velocity = input_dir * speed * zone_slow
	move_and_slide()
	# Если игрок вышел из трясины, замедление плавно сходит на нет.
	zone_slow = move_toward(zone_slow, 1.0, delta * 1.5)
	# Поворот фигуры по движению — только для запасного цветного кружка:
	# спрайт нарисован «лицом к камере», ему поворот не нужен.
	if velocity.length() > 10.0 and visual.visible:
		visual.rotation = velocity.angle() + PI / 2.0
	_animate_body(delta, input_dir)
	# ── Оружие: вся перезарядка и касты — в дочернем узле Weapons (player_weapons.gd).
	weapons.tick(delta)
	# Вспышка при уроне
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			set_body_modulate(Color.WHITE)

## Процедурная анимация: шаг — подпрыгивание и лёгкий наклон, покой — дыхание.
## Так спрайт «живёт» без покадровых спрайт-листов, а походка не разъезжается.
var _walk_phase: float = 0.0

func _animate_body(delta: float, input_dir: Vector2) -> void:
	if not body.visible:
		return
	var moving: bool = input_dir.length() > 0.1
	if absf(input_dir.x) > 0.05:
		body.flip_h = input_dir.x < 0.0

	if walk_frames.is_empty():
		# Процедурная анимация: подскок и наклон на шаге, «дыхание» в покое.
		if moving:
			_walk_phase += delta * 11.0
			var step: float = absf(sin(_walk_phase))
			body.position = Vector2(0, -6 - step * 3.0)
			body.rotation = sin(_walk_phase) * 0.09
			body.scale = Vector2(1.0 + step * 0.05, 1.0 - step * 0.07)
		else:
			_walk_phase = 0.0
			var breath: float = sin(Time.get_ticks_msec() / 420.0)
			body.position = Vector2(0, -6 + breath * 1.0)
			body.rotation = 0.0
			body.scale = Vector2(1.0 + breath * 0.015, 1.0 + breath * 0.015)
		return

	# Покадровая походка.
	if moving:
		_frame_time += delta
		if _frame_time >= 1.0 / WALK_FPS:
			_frame_time = 0.0
			_frame_index = (_frame_index + 1) % walk_frames.size()
			body.texture = walk_frames[_frame_index]
		# Подскок на «шаговых» кадрах и лёгкий наклон: сгенерированные позы
		# отличаются несильно, без этого походка читается как «слайд».
		var lift: float = 1.0 if _frame_index % 2 == 1 else 0.0
		body.position = Vector2(0, -6 - lift * 2.0)
		body.rotation = (0.04 if _frame_index == 1 else -0.04) if _frame_index % 2 == 1 else 0.0
		body.scale = Vector2(1.0 + lift * 0.03, 1.0 - lift * 0.04)
	else:
		_frame_time = 0.0
		_frame_index = 0
		body.texture = walk_frames[0]
		var breath2: float = sin(Time.get_ticks_msec() / 420.0)
		body.position = Vector2(0, -6 + breath2 * 1.0)
		body.rotation = 0.0
		body.scale = Vector2(1.0 + breath2 * 0.015, 1.0 + breath2 * 0.015)

# ── Ввод: WASD, стрелки, стик и крестовина геймпада (стик даёт аналоговый ход).
func get_input_vector() -> Vector2:
	# Движение через действия ввода: WASD, стрелки, левый стик и крестовина геймпада.
	# Стик даёт аналоговый ввод — можно идти вполсилы.
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() < 0.08:
		return Vector2.ZERO
	return v.limit_length(1.0)

# ── Авто-наведение: ближайший враг в радиусе, не занятый другими снарядами.
func find_nearest_enemy(exclude: Array = [], max_distance: float = 0.0):
	# Ближайший враг, которого нет в exclude, в пределах max_distance (0 = без лимита).
	var best = null
	var best_dist: float = 999999999.0
	var max_dist_sq: float = 999999999.0
	if max_distance > 0.0:
		max_dist_sq = max_distance * max_distance
	for enemy in Enemies.all():
		if exclude.has(enemy):
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_dist and d <= max_dist_sq:
			best_dist = d
			best = enemy
	return best

# ── Множители: замедление трясиной, уровни пассивок, масштаб урона и площади.
func apply_zone_slow(factor: float) -> void:
	# Вызывается зоной трясины каждый кадр, пока игрок внутри.
	zone_slow = minf(zone_slow, factor)

func passive_level(passive_id: String) -> int:
	return int(passive_levels.get(passive_id, 0))

func has_evo(evo_id: String) -> bool:
	return evolutions.has(evo_id)

func scaled_damage(base: int) -> int:
	# Все вызовы урона идут через этот множитель, поэтому перчатка
	# усиливает и базовые, и прокачанные характеристики.
	return maxi(1, int(round(float(base) * damage_mult)))

func scaled_area(radius: float) -> float:
	return radius * area_mult

## Доступные эволюции считаются из данных оружия (см. UpgradePool).
func get_available_evolutions() -> Array:
	return UpgradePool.available_evolutions(self)

# ── Пассивки и эволюции: выдача уровня пассивки и разблокировка эволюции оружия.
func apply_passive(passive_id: String) -> void:
	var def: Dictionary = PassiveData.by_id(passive_id)
	if def.is_empty():
		return
	var lvl: int = passive_level(passive_id)
	if lvl >= int(def["max"]):
		return
	passive_levels[passive_id] = lvl + 1
	_apply_stat_upgrade(def)
	AudioManager.play("levelup", -14.0)
	hp_changed.emit(hp, max_hp)
	stats_changed.emit()

func unlock_evolution(evo_id: String) -> void:
	if evolutions.has(evo_id):
		return
	evolutions.append(evo_id)
	# Постоянные бонусы берутся из данных; ситуативные эффекты
	# (лечение от новы, метеор, заморозка) проверяются через has_evo().
	for entry in WeaponData.evolution_effects(evo_id):
		_apply_stat_upgrade(entry)
	AudioManager.play("victory", -12.0)
	FX.burst(global_position, Color(1.0, 0.9, 0.4), 30, 180.0)
	stats_changed.emit()

# ── Оружие (каст, таймеры, сцены снарядов, клинки) — в scripts/player_weapons.gd.

# ── Урон игроку и лечение: броня, вспышка, тряска, сигнал HP, смерть.
func take_damage(amount: int) -> void:
	if dead:
		return
	var final_damage: int = maxi(1, amount - armor)
	AudioManager.play("hurt", -4.0)
	FX.burst(global_position, Color(1.0, 0.3, 0.3), 8, 100.0)
	FX.shake(0.45)
	FX.flash(Color(1.0, 0.1, 0.1), 0.30, 0.3)
	hp -= final_damage
	damage_taken += final_damage
	hp_changed.emit(hp, max_hp)
	set_body_modulate(Color(3.0, 1.2, 1.2))
	flash_timer = 0.1
	if hp <= 0:
		hp = 0
		dead = true
		died.emit()

func heal(amount: int) -> void:
	if dead:
		return
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

# ── Опыт и уровни: каждый 5-й уровень — выбор заклинания, остальные — улучшение.
func add_xp(amount: int) -> void:
	if dead:
		return
	xp += int(float(amount) * xp_multiplier)
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = xp_needed_for_level(level)
		# Каждый 5-й уровень — ОДИН выбор: два заклинания и усиление урона по центру.
		# Обычное улучшение за такой уровень не выдаётся, иначе получалось два выбора подряд.
		if level % 5 == 0:
			pending_spell_choices += 1
		else:
			pending_level_ups += 1
	xp_changed.emit(xp, xp_next, level)
	if pending_level_ups > 0 or pending_spell_choices > 0:
		leveled_up.emit()

func xp_needed_for_level(lvl: int) -> int:
	return int(5.0 + float(lvl - 1) * 4.0 + pow(float(lvl - 1), 1.6))

# ── Выбор улучшений: карточки уровня и эволюции за ядро мини-босса.
## Карточки на экране прокачки: пул собирается из данных (см. UpgradePool).
## Эволюций здесь больше нет — их выдаёт мини-босс, см. get_evolution_choices().
func get_upgrade_choices(count: int) -> Array:
	var pool: Array = UpgradePool.build(self)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

## Эволюции, доступные за ядро мини-босса. Пустой список — игрок получит обычные улучшения.
func get_evolution_choices(count: int = 3) -> Array:
	var available: Array = get_available_evolutions()
	available.shuffle()
	return available.slice(0, mini(count, available.size()))

# ── Отчёт для паузы: герой, оружие, пассивки, эволюции одним текстом.
func build_report() -> String:
	var lines: Array = []
	var char_data: Dictionary = Records.get_character(Records.selected_character)
	lines.append(Loc.t("ГЕРОЙ — %s") % Loc.t(str(char_data.get("name", "?"))))
	lines.append(Loc.t("HP %d / %d   •   Броня %d   •   Скорость %d") % [hp, max_hp, armor, int(speed)])
	lines.append(Loc.t("Урон оружия ×%.2f   •   Площадь ×%.2f   •   Опыт ×%.2f   •   Магнит %d") % [damage_mult, area_mult, xp_multiplier, int(magnet_radius)])
	lines.append("")
	var weapon_names: Dictionary = {}
	for spell in get_spell_choices_all():
		weapon_names[str(spell["id"])] = str(spell["title"])
	lines.append(Loc.t("ОРУЖИЕ (%d)") % unlocked_weapons.size())
	for weapon_id_raw in unlocked_weapons:
		var weapon_id: String = str(weapon_id_raw)
		var weapon_name: String = Loc.t(str(weapon_names.get(weapon_id, weapon_id)))
		lines.append("• %s — %s" % [weapon_name, weapon_details(weapon_id)])
	lines.append("")
	var owned_passives: Array = []
	for passive_def in passive_definitions:
		var pid: String = str(passive_def["id"])
		var lvl: int = passive_level(pid)
		if lvl > 0:
			owned_passives.append("• %s %d/%d — %s" % [Loc.t(str(passive_def["name"])), lvl, int(passive_def["max"]), Loc.t(str(passive_def["desc"]))])
	if owned_passives.size() > 0:
		lines.append(Loc.t("ПАССИВКИ (%d)") % owned_passives.size())
		lines.append_array(owned_passives)
		lines.append("")
	if evolutions.size() > 0:
		lines.append(Loc.t("ЭВОЛЮЦИИ (%d)") % evolutions.size())
		for evo_id_raw in evolutions:
			lines.append("• %s" % Loc.t(str(evolution_names.get(str(evo_id_raw), str(evo_id_raw)))))
	return "\n".join(PackedStringArray(lines))

## Все заклинания без фильтра «чего ещё нет» — нужно для названий в отчёте.
# ── Заклинания: открытие новых и карточки выбора (в отчёте нужны все названия).
func get_spell_choices_all() -> Array:
	return WeaponData.all_titles()

## Короткая сводка по оружию — формат и поля берутся из WeaponData.
func weapon_details(weapon_id: String) -> String:
	return WeaponData.details(self, weapon_id)

func get_spell_choices() -> Array:
	var remaining: Array = []
	for def in WeaponData.LIST:
		if not unlocked_weapons.has(str(def["id"])):
			remaining.append({"id": str(def["id"]), "title": str(def["title"]), "desc": str(def["desc"])})
	# Заклинаний больше, чем слотов (4) — показываем случайные 3.
	remaining.shuffle()
	return remaining.slice(0, mini(3, remaining.size()))

func unlock_spell(spell_id: String) -> void:
	if not unlocked_weapons.has(spell_id):
		unlocked_weapons.append(spell_id)
	if spell_id == "orbit":
		weapons.rebuild_orbit_blades()
	stats_changed.emit()

# ── Урон заклинаний: чтение, подъём на 50% и готовая карточка «+50% урону».
## Урон конкретного заклинания «как есть» (без общего множителя damage_mult).
func weapon_damage(weapon_id: String) -> int:
	var stat: String = str(WEAPON_DAMAGE_VARS.get(weapon_id, ""))
	if stat == "":
		return 0
	return int(get(stat))

## Поднять урон одного заклинания на LEVEL5_DAMAGE_BONUS (по умолчанию +50%).
func boost_weapon_damage(weapon_id: String) -> Dictionary:
	var stat: String = str(WEAPON_DAMAGE_VARS.get(weapon_id, ""))
	if stat == "":
		return {}
	var before: int = int(get(stat))
	# Минимум +1, иначе у слабых заклинаний бонус терялся в округлении.
	var after: int = maxi(before + 1, int(round(float(before) * LEVEL5_DAMAGE_BONUS)))
	set(stat, after)
	if weapon_id == "orbit":
		weapons.refresh_orbit_damage()
	elif weapon_id == "saw":
		pass # урон пилы передаётся при каждом спавне
	stats_changed.emit()
	return {"weapon": weapon_id, "before": before, "after": after}

## Случайное из открытых заклинаний, у которого есть переменная урона.
func random_boost_weapon() -> String:
	var candidates: Array = []
	for weapon_raw in unlocked_weapons:
		var weapon_id: String = str(weapon_raw)
		if WEAPON_DAMAGE_VARS.has(weapon_id):
			candidates.append(weapon_id)
	if candidates.is_empty():
		return ""
	return str(candidates[randi() % candidates.size()])

## Карточка «+50% урона заклинанию» — заклинание выбирается случайно здесь,
## чтобы игрок видел, у чего именно вырастет урон. id начинается с "boost:".
func make_boost_card(weapon_id: String) -> Dictionary:
	var weapon_name: String = Loc.t(WeaponData.title_of(weapon_id))
	var before: int = weapon_damage(weapon_id)
	var after: int = maxi(before + 1, int(round(float(before) * LEVEL5_DAMAGE_BONUS)))
	return {
		"id": "boost:%s" % weapon_id,
		"title": Loc.t("Урон +50%%: %s") % weapon_name,
		"desc": Loc.t("%d → %d урона") % [before, after],
		"kind": "boost",
	}

## Выбор на 5-м уровне: [заклинание, усиление урона, заклинание].
## Усиление всегда в центре (кнопка №2). Если заклинаний не хватает — добираем обычными картами.
func get_level5_choices() -> Array:
	var spells: Array = get_spell_choices()
	var boost_weapon: String = random_boost_weapon()
	var middle: Dictionary = {}
	if boost_weapon != "":
		middle = make_boost_card(boost_weapon)
	var spare: Array = get_upgrade_choices(6)
	var result: Array = []
	if spells.size() >= 2 and not middle.is_empty():
		var s0: Dictionary = (spells[0] as Dictionary).duplicate()
		s0["kind"] = "spell"
		var s1: Dictionary = (spells[1] as Dictionary).duplicate()
		s1["kind"] = "spell"
		result = [s0, middle, s1]
	elif spells.size() >= 1 and not middle.is_empty():
		var s0: Dictionary = (spells[0] as Dictionary).duplicate()
		s0["kind"] = "spell"
		result = [s0, middle, spare[0] if spare.size() > 0 else middle]
	else:
		# Заклинаний нет или усиление невозможно — обычные карты, усиление в центр.
		for card in spare:
			if result.size() >= 3:
				break
			if result.size() == 1 and not middle.is_empty():
				result.append(middle)
			result.append(card)
		if result.size() < 3 and not middle.is_empty() and not result.has(middle):
			result.insert(1, middle)
	return result.slice(0, 3)

# ── Применение улучшений: карточка → стата через _apply_stat_upgrade (op/value из данных).
func apply_upgrade(upgrade_id: String) -> void:
	# Карточка 5-го уровня: урон одному заклинанию.
	if upgrade_id.begins_with("boost:"):
		boost_weapon_damage(upgrade_id.trim_prefix("boost:"))
		return
	# Пассивка — отдельная ветка: у неё свои уровни.
	if UpgradePool.is_passive_upgrade(upgrade_id):
		apply_passive(upgrade_id.trim_prefix("passive_"))
		return
	if UpgradePool.is_evolution(upgrade_id):
		unlock_evolution(upgrade_id)
		return
	var entry: Dictionary = UpgradePool.find_entry(upgrade_id)
	if entry.is_empty():
		return
	_apply_stat_upgrade(entry)
	hp_changed.emit(hp, max_hp)
	stats_changed.emit()

## Универсальное применение улучшения по описанию из данных.
## op: add_int | mul_int | mul_float | mul_cooldown | sub_clamped | add_float | max_hp | heal
func _apply_stat_upgrade(entry: Dictionary) -> void:
	var op: String = str(entry.get("op", ""))
	var value: float = float(entry.get("value", 0.0))
	var stat: String = str(entry.get("stat", ""))
	match op:
		"add_int":
			var grown: int = int(get(stat)) + int(value)
			# Предел карты соблюдаем и при прямом применении, а не только в пуле.
			if entry.has("cap"):
				grown = mini(grown, int(entry["cap"]))
			set(stat, grown)
		"mul_int":
			set(stat, int(ceil(float(get(stat)) * value)))
		"mul_float":
			set(stat, float(get(stat)) * value)
		"mul_cooldown":
			set(stat, maxf(float(entry.get("min", 0.2)), float(get(stat)) * value))
		"sub_clamped":
			set(stat, maxf(float(entry.get("min", 0.0)), float(get(stat)) - value))
		"add_float":
			set(stat, float(get(stat)) + value)
		"set_int":
			set(stat, int(value))
		"set_float":
			set(stat, value)
		"max_hp":
			max_hp += int(value)
			heal(int(value))
		"heal":
			heal(int(value))
	if entry.has("after"):
		_run_weapon_hook(str(entry["after"]))

## Пересчёт производных значений после смены статы (клинки держат урон у себя).
func _run_weapon_hook(hook: String) -> void:
	match hook:
		"orbit_damage":
			weapons.refresh_orbit_damage()
		"orbit_rebuild":
			weapons.rebuild_orbit_blades()
		"orbit_size":
			weapons.apply_orbit_size()

