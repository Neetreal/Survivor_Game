class_name RunStats
extends RefCounted
## Статистика текущего забега для экрана результатов.
##
## Урон считается в одном месте — в `Enemy.take_damage()`: туда передаётся id источника
## («orbit», «bolt», …), и в зачёт идёт только тот урон, который реально прошёл
## (щит щитоносца, например, съедает попадание без урона).
## Так цифры на экране всегда сходятся с тем, что видел игрок в бою.

static var damage_by_source: Dictionary = {} # id источника -> нанесённый урон
static var gold_start: int = 0 # золото на старте забега
static var boss_spawn_time: float = 600.0 # когда появляется босс (секунды)
static var boss_killed_at: float = -1.0 # когда убили босса (-1 = не убили)

## Начать отсчёт заново (вызывается при старте забега).
static func reset() -> void:
	damage_by_source.clear()
	gold_start = Records.gold
	boss_spawn_time = 600.0
	boss_killed_at = -1.0

## Прибавить нанесённый урон к источнику.
static func add_damage(source_id: String, amount: int) -> void:
	if amount <= 0:
		return
	damage_by_source[source_id] = int(damage_by_source.get(source_id, 0)) + amount

static func total_damage() -> int:
	var total: int = 0
	for value in damage_by_source.values():
		total += int(value)
	return total

## Золото, заработанное именно в этом забеге.
static func gold_earned() -> int:
	return maxi(0, Records.gold - gold_start)

## Топ источников урона: [{id, name, damage, share(0..1)}], по убыванию.
static func top_sources(count: int) -> Array:
	var entries: Array = []
	for source_id in damage_by_source.keys():
		var damage: int = int(damage_by_source[source_id])
		if damage <= 0:
			continue
		entries.append({"id": str(source_id), "damage": damage})
	entries.sort_custom(func(a, b): return int(a["damage"]) > int(b["damage"]))
	var total: int = maxi(1, total_damage())
	var result: Array = []
	for i in range(mini(count, entries.size())):
		var entry: Dictionary = entries[i]
		result.append({
			"id": str(entry["id"]),
			"name": source_name(str(entry["id"])),
			"damage": int(entry["damage"]),
			"share": float(entry["damage"]) / float(total),
		})
	return result

## Урон от всего, что не попало в топ (для строки «остальное»).
static func rest_damage(count: int) -> int:
	var top: Array = top_sources(count)
	var shown: int = 0
	for entry in top:
		shown += int(entry["damage"])
	return maxi(0, total_damage() - shown)

## Человеческое название источника урона.
static func source_name(source_id: String) -> String:
	match source_id:
		"traps":
			return Loc.t("Ловушки арены")
		"other":
			return Loc.t("Прочее")
		_:
			var title: String = WeaponData.title_of(source_id)
			return Loc.t(title) if title != "" else Loc.t("Прочее")
