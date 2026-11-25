class_name WeaponData
extends RefCounted
## Всё, что описывает заклинание как контент: название, описание, строка характеристик,
## список улучшений и эволюция. Механика стрельбы остаётся в player.gd.
##
## Чтобы добавить 12-е заклинание, нужно:
##   1. дописать запись в LIST (данные + улучшения + эволюция);
##   2. написать одну функцию стрельбы в player.gd и завести её таймер.
## Не нужно: править пул улучшений, фильтры «открыто/не открыто», отчёт в паузе,
## список карточек выбора заклинания — всё это читается из LIST.
##
## Схема записи:
##   id           — строковый ключ (совпадает с unlocked_weapons)
##   title / desc — карточка выбора заклинания (переводятся в Loc)
##   details_format / details_stats — строка характеристик в меню паузы:
##        "имя_поля" | "имя_поля:int" | "имя_поля:slow_percent"
##   upgrades     — карточки улучшений: stat + op + value (+ min, after)
##        op: add_int | mul_int | mul_float | mul_cooldown | sub_clamped | add_float
##        after: orbit_damage | orbit_rebuild | orbit_size (пересчёт после смены статы)
##   evolution    — {id, name, desc, passive, passive_level} — необязательно

const LIST: Array = [
	{
		"id": "bolt",
		"title": "Стрелы",
		"desc": "Лучник бьёт стрелами по ближайшим врагам",
		"details_format": "%d урона, стрел: %d, пробитие %s, %.2f с",
		"details_stats": ["bolt_damage:int", "bolt_count:int", "bolt_pierce:pierce", "bolt_cooldown"],
		"upgrades": [
			{"id": "bolt_damage", "title": "Заточка +25%", "desc": "Стрелы наносят больше урона", "stat": "bolt_damage", "op": "mul_int", "value": 1.25},
			{"id": "bolt_speed", "title": "Скорострельность +20%", "desc": "Стрелы летят чаще", "stat": "bolt_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.25},
			{"id": "bolt_count", "title": "+1 стрела", "desc": "Выпускать ещё одну стрелу за раз", "stat": "bolt_count", "op": "add_int", "value": 1},
			{"id": "bolt_pierce", "title": "Пробитие +1", "desc": "Стрела проходит сквозь ещё одного врага", "stat": "bolt_pierce", "op": "add_int", "value": 1, "cap": 4},
			{"id": "bolt_ricochet", "title": "Рикошет +1", "desc": "После попадания стрела скачет в следующего врага", "stat": "bolt_ricochet", "op": "add_int", "value": 1, "cap": 2},
		],
		# У снарядов две ветки эволюции — панель ядра предложит на выбор обе.
		"evolutions": [
			{"id": "evo_bolt", "name": "Залп", "desc": "Стрелы пробивают всех на линии, +2 стрелы, +40% урона, шире веер", "apply": [
				{"stat": "bolt_pierce", "op": "set_int", "value": 999},
				{"stat": "bolt_count", "op": "add_int", "value": 2},
				{"stat": "bolt_damage", "op": "mul_int", "value": 1.4},
				{"stat": "bolt_speed", "op": "mul_float", "value": 1.25},
			]},
			{"id": "evo_bolt_kara", "name": "Кара", "desc": "Стрелы сами поворачивают за целью, +60% урона, +1 стрела, чаще", "apply": [
				{"stat": "bolt_homing", "op": "set_float", "value": 3.84},
				{"stat": "bolt_damage", "op": "mul_int", "value": 1.6},
				{"stat": "bolt_count", "op": "add_int", "value": 1},
				{"stat": "bolt_cooldown", "op": "mul_cooldown", "value": 0.85, "min": 0.25},
			]},
		],
	},
	{
		"id": "orbit",
		"title": "Клинки на орбите",
		"desc": "Клинки вращаются вокруг тебя",
		"details_format": "%d урона, %d клинок(а), %.1f об/с",
		"details_stats": ["orbit_damage:int", "orbit_blade_count:int", "orbit_rotation_speed"],
		"upgrades": [
			{"id": "orbit_damage", "title": "Клинки +30% урона", "desc": "Клинки на орбите бьют сильнее", "stat": "orbit_damage", "op": "mul_int", "value": 1.3, "after": "orbit_damage"},
			{"id": "orbit_count", "title": "+1 клинок", "desc": "Ещё один клинок вокруг тебя", "stat": "orbit_blade_count", "op": "add_int", "value": 1, "after": "orbit_rebuild"},
			{"id": "orbit_size", "title": "Размер клинков +25%", "desc": "Клинки больше и бьют по большей площади", "stat": "orbit_blade_size", "op": "mul_float", "value": 1.25, "after": "orbit_size"},
			{"id": "orbit_speed", "title": "Орбита быстрее +25%", "desc": "Клинки вращаются быстрее", "stat": "orbit_rotation_speed", "op": "mul_float", "value": 1.25},
		],
		"evolution": {"id": "evo_orbit", "name": "Вихрь", "desc": "Клинки ходят по спирали, расширяясь и сжимаясь", "passive": "candle", "passive_level": 3, "apply": [{"stat": "orbit_rotation_speed", "op": "mul_float", "value": 1.3}]},
	},
	{
		"id": "nova",
		"title": "Нова",
		"desc": "Импульс по площади вокруг",
		"details_format": "%d урона, радиус %d, %.2f с",
		"details_stats": ["nova_damage:int", "nova_radius:int", "nova_cooldown"],
		"upgrades": [
			{"id": "nova_damage", "title": "Нова +30% урона", "desc": "Импульс по площади бьёт сильнее", "stat": "nova_damage", "op": "mul_int", "value": 1.3},
			{"id": "nova_radius", "title": "Нова +25% радиуса", "desc": "Импульс накрывает большую площадь", "stat": "nova_radius", "op": "mul_float", "value": 1.25},
			{"id": "nova_speed", "title": "Нова чаще +20%", "desc": "Импульс срабатывает быстрее", "stat": "nova_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.8},
		],
		"evolution": {"id": "evo_nova", "name": "Взрывная волна", "desc": "Нова лечит на 5% нанесённого урона", "passive": "heart", "passive_level": 3},
	},
	{
		"id": "chain",
		"title": "Цепная молния",
		"desc": "Молния перескакивает между врагами",
		"details_format": "%d урона, %d перескок(а), %.2f с",
		"details_stats": ["chain_damage:int", "chain_jumps:int", "chain_cooldown"],
		"upgrades": [
			{"id": "chain_damage", "title": "Молния +30% урона", "desc": "Цепная молния бьёт сильнее", "stat": "chain_damage", "op": "mul_int", "value": 1.3},
			{"id": "chain_speed", "title": "Молния чаще +20%", "desc": "Молния срабатывает быстрее", "stat": "chain_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.6},
			{"id": "chain_jumps", "title": "+1 цепь молнии", "desc": "Молния перескакивает ещё на одного врага", "stat": "chain_jumps", "op": "add_int", "value": 1},
			{"id": "chain_range", "title": "Молния +25% дальности", "desc": "Молния находит цели дальше", "stat": "chain_range", "op": "mul_float", "value": 1.25},
		],
		"evolution": {"id": "evo_chain", "name": "Гроза", "desc": "Молния достаёт до всех врагов на экране", "passive": "glove", "passive_level": 3, "apply": [{"stat": "chain_jumps", "op": "add_int", "value": 3}]},
	},
	{
		"id": "fireball",
		"title": "Огненный шар",
		"desc": "Взрывается по площади при попадании",
		"details_format": "%d урона, %d шар(а), взрыв %d, %.2f с",
		"details_stats": ["fire_damage:int", "fire_count:int", "fire_radius:int", "fire_cooldown"],
		"upgrades": [
			{"id": "fire_damage", "title": "Огонь +30% урона", "desc": "Взрывы огненного шара сильнее", "stat": "fire_damage", "op": "mul_int", "value": 1.3},
			{"id": "fire_speed", "title": "Огонь чаще +20%", "desc": "Шары летят быстрее", "stat": "fire_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.5},
			{"id": "fire_count", "title": "+1 огненный шар", "desc": "Выпускать ещё один шар за раз", "stat": "fire_count", "op": "add_int", "value": 1},
			{"id": "fire_radius", "title": "Взрыв +25%", "desc": "Взрывы накрывают большую площадь", "stat": "fire_radius", "op": "mul_float", "value": 1.25},
		],
		"evolution": {"id": "evo_fire", "name": "Метеор", "desc": "Взрыв в 1.8 раза шире и на 40% сильнее", "passive": "candle", "passive_level": 3},
	},
	{
		"id": "frost",
		"title": "Ледяная аура",
		"desc": "Замедляет врагов вокруг тебя",
		"details_format": "%d урона/тик, радиус %d, замедление %d%%",
		"details_stats": ["frost_damage:int", "frost_radius:int", "frost_slow:slow_percent"],
		"upgrades": [
			{"id": "frost_damage", "title": "Мороз +50% урона", "desc": "Аура наносит больше урона", "stat": "frost_damage", "op": "mul_int", "value": 1.5},
			{"id": "frost_radius", "title": "Мороз +25% радиуса", "desc": "Аура накрывает большую площадь", "stat": "frost_radius", "op": "mul_float", "value": 1.25},
			{"id": "frost_slow", "title": "Мороз сильнее", "desc": "Враги замедляются сильнее", "stat": "frost_slow", "op": "sub_clamped", "value": 0.08, "min": 0.25},
		],
		"evolution": {"id": "evo_frost", "name": "Заморозка", "desc": "Замороженные враги разбиваются и бьют соседей", "passive": "glove", "passive_level": 3},
	},
	{
		"id": "boomerang",
		"title": "Бумеранг",
		"desc": "Улетает и возвращается, бьёт дважды",
		"details_format": "%d урона, %d бумеранг(а), %.2f с",
		"details_stats": ["boom_damage:int", "boom_count:int", "boom_cooldown"],
		"upgrades": [
			{"id": "boom_damage", "title": "Бумеранг +30% урона", "desc": "Бумеранг бьёт сильнее", "stat": "boom_damage", "op": "mul_int", "value": 1.3},
			{"id": "boom_speed", "title": "Бумеранг чаще +20%", "desc": "Бумеранг возвращается быстрее", "stat": "boom_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.6},
			{"id": "boom_count", "title": "+1 бумеранг", "desc": "Бросать ещё один бумеранг", "stat": "boom_count", "op": "add_int", "value": 1},
		],
		"evolution": {"id": "evo_boom", "name": "Пила", "desc": "+2 бумеранга, летят сквозь врагов", "passive": "boots", "passive_level": 3, "apply": [{"stat": "boom_count", "op": "add_int", "value": 2}]},
	},
	{
		"id": "spear",
		"title": "Копьё",
		"desc": "Пробивает врагов насквозь по прямой",
		"details_format": "%d урона, %d копьё(й), пробивает, %.2f с",
		"details_stats": ["spear_damage:int", "spear_count:int", "spear_cooldown"],
		"upgrades": [
			{"id": "spear_damage", "title": "Копьё +30% урона", "desc": "Копьё пробивает строй и бьёт сильнее", "stat": "spear_damage", "op": "mul_int", "value": 1.3},
			{"id": "spear_speed", "title": "Копьё чаще +20%", "desc": "Копьё метается чаще", "stat": "spear_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.7},
			{"id": "spear_count", "title": "+1 копьё", "desc": "Метать ещё одно копьё за раз", "stat": "spear_count", "op": "add_int", "value": 1},
			{"id": "spear_range", "title": "Копьё +25% дальности", "desc": "Копьё летит дальше", "stat": "spear_range", "op": "mul_float", "value": 1.25},
		],
	},
	{
		"id": "mine",
		"title": "Мины",
		"desc": "Кладёт мины под ноги, взрыв бьёт по площади",
		"details_format": "%d урона, %d мина(ы), взрыв %d, %.2f с",
		"details_stats": ["mine_damage:int", "mine_count:int", "mine_radius:int", "mine_cooldown"],
		"upgrades": [
			{"id": "mine_damage", "title": "Мина +30% урона", "desc": "Взрыв мины бьёт сильнее", "stat": "mine_damage", "op": "mul_int", "value": 1.3},
			{"id": "mine_speed", "title": "Мины чаще +20%", "desc": "Класть мины чаще", "stat": "mine_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 1.0},
			{"id": "mine_count", "title": "+1 мина", "desc": "Класть ещё одну мину за раз", "stat": "mine_count", "op": "add_int", "value": 1},
			{"id": "mine_radius", "title": "Взрыв мины +25%", "desc": "Мина накрывает большую площадь", "stat": "mine_radius", "op": "mul_float", "value": 1.25},
		],
	},
	{
		"id": "poison",
		"title": "Ядовитое облако",
		"desc": "Лужа яда травит врагов несколько секунд",
		"details_format": "%d урона/тик, радиус %d, %.2f с",
		"details_stats": ["poison_damage:int", "poison_radius:int", "poison_cooldown"],
		"upgrades": [
			{"id": "poison_damage", "title": "Яд +40% урона", "desc": "Облако травит сильнее", "stat": "poison_damage", "op": "mul_int", "value": 1.4},
			{"id": "poison_radius", "title": "Облако +25% радиуса", "desc": "Ядовитое облако шире", "stat": "poison_radius", "op": "mul_float", "value": 1.25},
			{"id": "poison_speed", "title": "Яд чаще +20%", "desc": "Облако появляется чаще", "stat": "poison_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 1.0},
		],
	},
	{
		"id": "saw",
		"title": "Пила",
		"desc": "Кружит по широкой орбите и режет всех",
		"details_format": "%d урона, %d пила(ы), орбита %d, %.2f с",
		"details_stats": ["saw_damage:int", "saw_count:int", "saw_radius:int", "saw_cooldown"],
		"upgrades": [
			{"id": "saw_damage", "title": "Пила +30% урона", "desc": "Пила режет сильнее", "stat": "saw_damage", "op": "mul_int", "value": 1.3},
			{"id": "saw_speed", "title": "Пила чаще +20%", "desc": "Запускать пилу чаще", "stat": "saw_cooldown", "op": "mul_cooldown", "value": 0.82, "min": 0.8},
			{"id": "saw_count", "title": "+1 пила", "desc": "Запускать две пилы сразу", "stat": "saw_count", "op": "add_int", "value": 1},
			{"id": "saw_radius", "title": "Пила +20% радиуса", "desc": "Пила кружит шире", "stat": "saw_radius", "op": "mul_float", "value": 1.2},
		],
	},
]

static func by_id(weapon_id: String) -> Dictionary:
	for def in LIST:
		if str(def["id"]) == weapon_id:
			return def
	return {}

static func all_ids() -> Array:
	var ids: Array = []
	for def in LIST:
		ids.append(str(def["id"]))
	return ids

static func all_titles() -> Array:
	var list: Array = []
	for def in LIST:
		list.append({"id": str(def["id"]), "title": str(def["title"])})
	return list

static func title_of(weapon_id: String) -> String:
	return str(by_id(weapon_id).get("title", weapon_id))

## Все улучшения всех заклинаний (без фильтра «что открыто»).
static func all_upgrades() -> Array:
	var list: Array = []
	for def in LIST:
		for upgrade in def.get("upgrades", []):
			list.append(upgrade)
	return list

## Список эволюций заклинания: в данных допустимы и "evolution" (одна), и "evolutions" (несколько).
static func evolutions_of(def: Dictionary) -> Array:
	if def.has("evolutions"):
		return def["evolutions"]
	var single: Dictionary = def.get("evolution", {})
	return [single] if not single.is_empty() else []

static func evolution_name(evo_id: String) -> String:
	for def in LIST:
		for evo in evolutions_of(def):
			if str(evo["id"]) == evo_id:
				return str(evo["name"])
	return "Эволюция"

static func evolution_names() -> Dictionary:
	var names: Dictionary = {}
	for def in LIST:
		for evo in evolutions_of(def):
			names[str(evo["id"])] = str(evo["name"])
	return names

## Строка характеристик для меню паузы: «26 урона, 1 копьё(й), пробивает, 2.00 с».
static func details(player: Node, weapon_id: String) -> String:
	var def: Dictionary = by_id(weapon_id)
	if def.is_empty() or not def.has("details_format"):
		return "—"
	var values: Array = []
	for spec in def.get("details_stats", []):
		values.append(_stat_value(player, str(spec)))
	return Loc.t(str(def["details_format"])) % values

static func _stat_value(player: Node, spec: String) -> Variant:
	var parts: PackedStringArray = spec.split(":")
	var stat: String = parts[0]
	var mode: String = parts[1] if parts.size() > 1 else ""
	var value = player.get(stat)
	match mode:
		"int":
			return int(value)
		"pierce":
			# 999 — пробитие без предела (эволюция «Залп»), в строке пишем «все».
			return Loc.t("все") if int(value) >= 99 else str(int(value))
		"slow_percent":
			# frost_slow = 0.5 значит «замедление 50%»
			return int((1.0 - float(value)) * 100.0)
	return value

## Постоянные бонусы эволюции (ситуативные проверяются через has_evo() в коде стрельбы).
static func evolution_effects(evo_id: String) -> Array:
	for def in LIST:
		for evo in evolutions_of(def):
			if str(evo["id"]) == evo_id:
				return evo.get("apply", [])
	return []

## Первое заклинание, к которому относится эволюция (для отчёта и поиска).
static func weapon_of_evolution(evo_id: String) -> Dictionary:
	for def in LIST:
		for evo in evolutions_of(def):
			if str(evo["id"]) == evo_id:
				return def
	return {}
