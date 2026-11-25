class_name PassiveData
extends RefCounted
## Пассивные предметы — только данные.
## Механика применения лежит в player.gd (`_apply_stat_upgrade`), потому что ей нужны
## живые поля игрока. Здесь: id, названия, описание, потолок уровней и что даёт уровень.
##
## Чтобы добавить пассивку: дописать запись в LIST. Больше ничего не нужно —
## она сама появится в пуле улучшений, в отчёте паузы и в описании сборки.

const LIST: Array = [
	{
		"id": "book",
		"name": "Книга мудрости",
		"short": "Книга",
		"desc": "+10% получаемого опыта",
		"max": 5,
		# Что делает каждый уровень пассивки
		"stat": "xp_multiplier",
		"op": "mul_float",
		"value": 1.1,
	},
	{
		"id": "candle",
		"name": "Свеча",
		"short": "Свеча",
		"desc": "+8% к площади и дальности оружия",
		"max": 5,
		"stat": "area_mult",
		"op": "mul_float",
		"value": 1.08,
	},
	{
		"id": "glove",
		"name": "Боевая перчатка",
		"short": "Перчатка",
		"desc": "+6% к урону всего оружия",
		"max": 5,
		"stat": "damage_mult",
		"op": "mul_float",
		"value": 1.06,
		"after": "orbit_damage", # клинки держат урон в своих свойствах — их надо обновить
	},
	{
		"id": "boots",
		"name": "Сапоги скорости",
		"short": "Сапоги",
		"desc": "+4% к скорости бега",
		"max": 5,
		"stat": "speed",
		"op": "mul_float",
		"value": 1.04,
	},
	{
		"id": "heart",
		"name": "Сердце гиганта",
		"short": "Сердце",
		"desc": "+15 к максимуму здоровья",
		"max": 5,
		"op": "max_hp",
		"value": 15,
	},
	{
		"id": "magnet",
		"name": "Магнит",
		"short": "Магнит",
		"desc": "+20 к радиусу сбора кристаллов",
		"max": 5,
		"stat": "magnet_radius",
		"op": "add_float",
		"value": 20.0,
	},
]

static func by_id(passive_id: String) -> Dictionary:
	for def in LIST:
		if str(def["id"]) == passive_id:
			return def
	return {}

static func name_of(passive_id: String) -> String:
	return str(by_id(passive_id).get("name", passive_id))

static func max_level(passive_id: String) -> int:
	return int(by_id(passive_id).get("max", 5))
