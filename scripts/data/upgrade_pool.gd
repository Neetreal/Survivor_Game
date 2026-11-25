class_name UpgradePool
extends RefCounted
## Сборка пула улучшений для экрана прокачки.
##
## Раньше это был один метод на 150 строк в player.gd с ручным списком из 38 улучшений
## и десятком «if begins_with(...) and not unlocked_weapons.has(...)» — добавление
## заклинания требовало правок в трёх местах. Теперь пул собирается из данных:
##   * улучшения заклинаний  → WeaponData.LIST (только для открытых заклинаний);
##   * общие улучшения героя → GENERIC (ниже);
##   * пассивные предметы    → PassiveData.LIST (только не на максимуме);
##   * эволюции              → НЕ здесь: их выдаёт мини-босс (см. main.gd).

## Общие улучшения: не привязаны к заклинанию, доступны всегда.
const GENERIC: Array = [
	{"id": "move_speed", "title": "Скорость +12%", "desc": "Бегай быстрее", "stat": "speed", "op": "mul_float", "value": 1.12},
	{"id": "max_hp", "title": "+20 к здоровью", "desc": "Максимум HP +20 и лечение на 20", "op": "max_hp", "value": 20},
	{"id": "armor", "title": "Броня +1", "desc": "Входящий урон уменьшается на 1", "stat": "armor", "op": "add_int", "value": 1},
	{"id": "magnet", "title": "Магнит +60%", "desc": "Кристаллы притягиваются с большего расстояния", "stat": "magnet_radius", "op": "mul_float", "value": 1.6},
	{"id": "heal", "title": "Лечение +40 HP", "desc": "Сразу восстановить 40 здоровья", "op": "heal", "value": 40},
	{"id": "xp_gain", "title": "Опыт +15%", "desc": "Кристаллы дают больше опыта", "stat": "xp_multiplier", "op": "mul_float", "value": 1.15},
]

## Доступные эволюции: заклинание изучено, эволюция ещё не взята.
## Требования к пассивке больше нет: эволюции выдаются за мини-боссов (`main.on_evo_core_collected`),
## а не за собранный билд. Заклинание всё ещё должно быть изучено — эволюция не появляется
## из ниоткуда и усиливает именно то оружие, которое у игрока есть.
static func available_evolutions(player: Node) -> Array:
	var list: Array = []
	var unlocked: Array = player.get("unlocked_weapons")
	var taken: Array = player.get("evolutions")
	for def in WeaponData.LIST:
		if not unlocked.has(str(def["id"])):
			continue
		for evo in WeaponData.evolutions_of(def):
			if taken.has(str(evo["id"])):
				continue
			list.append({
				"id": str(evo["id"]),
				"title": "ЭВОЛЮЦИЯ: %s" % str(evo["name"]),
				"desc": str(evo["desc"]),
			})
	return list

## Полный пул карточек (без эволюций — их подмешивает player.get_upgrade_choices).
static func build(player: Node) -> Array:
	var pool: Array = []
	var unlocked: Array = player.get("unlocked_weapons")
	for def in WeaponData.LIST:
		if not unlocked.has(str(def["id"])):
			continue
		for upgrade in def.get("upgrades", []):
			if not _under_cap(player, upgrade):
				continue
			pool.append(upgrade)
	pool.append_array(GENERIC)
	for passive_def in PassiveData.LIST:
		var passive_id: String = str(passive_def["id"])
		var level: int = int(player.call("passive_level", passive_id))
		var max_level: int = int(passive_def["max"])
		if level >= max_level:
			continue
		pool.append({
			"id": "passive_" + passive_id,
			"title": "%s %d→%d" % [str(passive_def["name"]), level, level + 1],
			"desc": str(passive_def["desc"]),
		})
	return pool

## Карта с пределом ("cap") перестаёт появляться, когда стата добралась до предела.
## Так «Пробитие +1» не копится бесконечно и не ломает забег.
static func _under_cap(player: Node, upgrade: Dictionary) -> bool:
	if not upgrade.has("cap"):
		return true
	var stat: String = str(upgrade.get("stat", ""))
	if stat == "":
		return true
	return int(player.get(stat)) < int(upgrade["cap"])

## Найти описание улучшения по id (нужно при применении).
static func find_entry(upgrade_id: String) -> Dictionary:
	for def in WeaponData.LIST:
		for upgrade in def.get("upgrades", []):
			if str(upgrade["id"]) == upgrade_id:
				return upgrade
	for entry in GENERIC:
		if str(entry["id"]) == upgrade_id:
			return entry
	return {}

static func is_passive_upgrade(upgrade_id: String) -> bool:
	return upgrade_id.begins_with("passive_")

static func is_evolution(upgrade_id: String) -> bool:
	return upgrade_id.begins_with("evo_")
