extends Node
## Синглтон (автозагрузка) для рекордов.
## Хранит лучшие результаты и историю забегов в user://records.cfg.
## Доступ из любого скрипта как Records.best_time, Records.save_run(...) и т.д.

const SAVE_PATH: String = "user://records.cfg"
const MAX_HISTORY: int = 10
## Копия сохранения перед сбросом: если игрок передумал, файл можно вернуть вручную.
const BACKUP_PATH: String = "user://records_backup.cfg"

var best_time: float = 0.0
var best_kills: int = 0
var best_level: int = 1
var history: Array = [] # Array of Dictionary: {time, kills, level, date}
var selected_character: String = "archer"
var selected_difficulty: String = "normal" # easy / normal / hard
## ================= КАРТЫ (БИОМЫ) =================
## slow_zones: количество зон, замедляющих всех внутри (0 — карта без зон).
var map_definitions: Array = [
	{
		"id": "forest",
		"name": "Лес",
		"desc": "Ровная зелёная арена без сюрпризов.",
		"background": Color(0.13, 0.18, 0.13),
		"decor": Color(0.2, 0.26, 0.2),
		"slow_zones": 0,
	},
	{
		"id": "bog",
		"name": "Топкие болота",
		"desc": "8 трясинных зон замедляют всех внутри — и тебя, и врагов.",
		"background": Color(0.09, 0.13, 0.11),
		"decor": Color(0.16, 0.24, 0.16),
		"slow_zones": 8,
	},
	{
		"id": "arena",
		"name": "Арена",
		"desc": "Каждые 6.5 с — ловушки: метеориты и шипы. Бьют всех, зато золота +25% и врагов больше.",
		"background": Color(0.16, 0.14, 0.19),
		"decor": Color(0.25, 0.22, 0.28),
		"slow_zones": 0,
		"traps": true,
		"enemy_cap_bonus": 15,
		"gold_bonus": 1.25,
	},
]
var selected_map: String = "forest"
## Множители сложности. Игра читает их через Records.difficulty_value("ключ").
var difficulty_definitions: Dictionary = {
	"easy": {
		"name": "Лёгкая",
		"desc": "Враги слабее и реже, урона меньше, опыта больше. Для первого знакомства.",
		"enemy_hp": 0.65,
		"enemy_damage": 0.6,
		"enemy_speed": 0.92,
		"boss_hp": 0.7,
		"spawn_interval": 1.35,
		"batch": 0.7,
		"elite_interval": 105.0,
		"enemy_cap": 90.0,
		"gold": 1.0,
		"xp": 1.15,
	},
	"normal": {
		"name": "Нормальная",
		"desc": "Стандартный баланс: как задумано авторами.",
		"enemy_hp": 1.0,
		"enemy_damage": 1.0,
		"enemy_speed": 1.0,
		"boss_hp": 1.0,
		"spawn_interval": 1.0,
		"batch": 1.0,
		"elite_interval": 75.0,
		"enemy_cap": 120.0,
		"gold": 1.0,
		"xp": 1.0,
	},
	"hard": {
		"name": "Сложная",
		"desc": "Врагов больше и они злее, опыта меньше, но золота в 1.5 раза больше.",
		"enemy_hp": 1.4,
		"enemy_damage": 1.45,
		"enemy_speed": 1.08,
		"boss_hp": 1.35,
		"spawn_interval": 0.78,
		"batch": 1.35,
		"elite_interval": 55.0,
		"enemy_cap": 150.0,
		"gold": 1.5,
		"xp": 0.9,
	},
}
var settings_volume: float = 0.8 # 0.0 .. 1.0
var settings_quality: int = 1 # 0 низкое, 1 среднее, 2 высокое (бюджет частиц, цифры урона)
var settings_fps: bool = false # Показывать счётчик кадров в бою
var settings_damage_numbers: bool = true # Цифры урона в бою
var settings_flashes: bool = true # Вспышки экрана (тряска настраивается отдельно)
var settings_shake: int = 0 # 0 обычная, 1 слабая, 2 выключена
var settings_ui_scale: int = 1 # 0 мелкий (90%), 1 обычный (100%), 2 крупный (120%)
var settings_language: String = "ru" # ru / en
var settings_screen_mode: int = 0 # 0 оконный, 1 во весь экран, 2 без рамки
var gold: int = 0
var meta_upgrades: Dictionary = {"vitality": 0, "power": 0, "swift": 0, "guard": 0, "magnet": 0, "wisdom": 0}
var meta_definitions: Array = [
	{"id": "vitality", "name": "Живучесть", "desc": "+10 к макс. здоровью", "max_level": 10, "base_cost": 30},
	{"id": "power", "name": "Сила", "desc": "+5% к урону всего оружия", "max_level": 10, "base_cost": 50},
	{"id": "swift", "name": "Скорость", "desc": "+2% к скорости бега", "max_level": 5, "base_cost": 40},
	{"id": "guard", "name": "Броня", "desc": "+1 к броне", "max_level": 5, "base_cost": 70},
	{"id": "magnet", "name": "Магнит", "desc": "+15 к радиусу притяжения", "max_level": 5, "base_cost": 25},
	{"id": "wisdom", "name": "Мудрость", "desc": "+3% к опыту", "max_level": 5, "base_cost": 40},
]
## ================= ДОСТИЖЕНИЯ =================
var achievements: Dictionary = {} # id -> true
var achievement_definitions: Array = [
	{"id": "first_blood", "name": "Первая кровь", "desc": "Убить 100 врагов за забег", "gold": 50},
	{"id": "kills500", "name": "Мясорубка", "desc": "Убить 500 врагов за забег", "gold": 100},
	{"id": "kills1000", "name": "Косарь", "desc": "Убить 1000 врагов за забег", "gold": 200},
	{"id": "survive5", "name": "Пятиминутка", "desc": "Дожить до 5:00", "gold": 100},
	{"id": "survive10", "name": "Десятиминутка", "desc": "Дожить до 10:00", "gold": 150},
	{"id": "level10", "name": "Десятка", "desc": "Достичь 10 уровня", "gold": 100},
	{"id": "level20", "name": "Двадцатка", "desc": "Достичь 20 уровня", "gold": 200},
	{"id": "level30", "name": "Тридцатка", "desc": "Достичь 30 уровня", "gold": 300},
	{"id": "boss_slayer", "name": "Убийца боссов", "desc": "Победить босса", "gold": 300},
	{"id": "victory_easy", "name": "Разминка", "desc": "Победить на лёгкой сложности", "gold": 150},
	{"id": "victory_hard", "name": "Настоящий выживальщик", "desc": "Победить на сложной сложности", "gold": 500},
	{"id": "evo1", "name": "Первый шаг эволюции", "desc": "Открыть первую эволюцию оружия", "gold": 100},
	{"id": "evo3", "name": "Мастер эволюций", "desc": "Открыть 3 эволюции за один забег", "gold": 250},
	{"id": "all_weapons", "name": "Арсенал", "desc": "Собрать 4 заклинания за забег", "gold": 150},
	{"id": "no_damage", "name": "Неприкасаемый", "desc": "Дожить до 5:00 без единого удара", "gold": 400},
	{"id": "miniboss", "name": "Охотник", "desc": "Убить мини-босса", "gold": 100},
	{"id": "gold1000", "name": "Богач", "desc": "Заработать 1000 золота всего", "gold": 200},
	{"id": "all_heroes", "name": "Все герои", "desc": "Сыграть за каждого героя", "gold": 250},
	{"id": "spell_master", "name": "Коллекционер", "desc": "Открыть 8 разных заклинаний хотя бы раз", "gold": 300},
	{"id": "marathon", "name": "Марафонец", "desc": "Провести в игре суммарно 30 минут", "gold": 200},
]

## ================= ПРОФИЛЬ =================
var profile: Dictionary = {
	"total_runs": 0,
	"total_kills": 0,
	"total_time": 0.0,
	"total_gold": 0,
	"victories": 0,
	"deaths": 0,
	"boss_kills": 0,
	"best_kills": 0,
	"heroes": {}, # id героя -> забегов
	"difficulties": {}, # id сложности -> забегов
	"spells_seen": {}, # id заклинания -> true
}

var characters: Array = [
	{"id": "archer", "name": "Лучник", "spell": "bolt", "spell_name": "Стрелы", "desc": "Сбалансированный боец", "max_hp": 100, "speed": 230.0, "armor": 0, "magnet": 95.0, "color": Color(0.45, 0.78, 0.35)},
	{"id": "knight", "name": "Рыцарь", "spell": "orbit", "spell_name": "Клинки на орбите", "desc": "Живучий и бронированный, но медленный", "max_hp": 150, "speed": 205.0, "armor": 2, "magnet": 80.0, "color": Color(0.9, 0.85, 0.4)},
	{"id": "storm", "name": "Грозовой маг", "spell": "chain", "spell_name": "Цепная молния", "desc": "Быстрый и хрупкий", "max_hp": 80, "speed": 250.0, "armor": 0, "magnet": 95.0, "color": Color(0.65, 0.45, 0.95)},
	{"id": "druid", "name": "Друид", "spell": "nova", "spell_name": "Нова", "desc": "Большой магнит для кристаллов", "max_hp": 110, "speed": 220.0, "armor": 0, "magnet": 140.0, "color": Color(0.45, 0.85, 0.35)},
	{"id": "fire", "name": "Огненный маг", "spell": "fireball", "spell_name": "Огненный шар", "desc": "Хрупкий, но жжёт толпы площадью", "max_hp": 75, "speed": 240.0, "armor": 0, "magnet": 90.0, "color": Color(1.0, 0.45, 0.2)},
]

func _ready() -> void:
	load_records()
	apply_volume()
	apply_screen_mode()

func load_records() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # Первый запуск — остаются значения по умолчанию
	best_time = float(cfg.get_value("best", "time", 0.0))
	best_kills = int(cfg.get_value("best", "kills", 0))
	best_level = int(cfg.get_value("best", "level", 1))
	history = cfg.get_value("history", "runs", [])
	selected_character = str(cfg.get_value("settings", "character", "archer"))
	# Совместимость: раньше стартовый герой назывался «mage» — теперь это «Лучник» (archer).
	if selected_character == "mage":
		selected_character = "archer"
	selected_difficulty = str(cfg.get_value("settings", "difficulty", "normal"))
	selected_map = str(cfg.get_value("settings", "map", "forest"))
	settings_volume = float(cfg.get_value("settings", "volume", 0.8))
	# Совместимость: раньше была галочка «Частицы»; выключенная = низкое качество.
	var legacy_particles: bool = bool(cfg.get_value("settings", "particles", true))
	settings_quality = clampi(int(cfg.get_value("settings", "quality", 1 if legacy_particles else 0)), 0, 2)
	settings_fps = bool(cfg.get_value("settings", "fps", false))
	settings_shake = clampi(int(cfg.get_value("settings", "shake", 0)), 0, 2)
	settings_ui_scale = clampi(int(cfg.get_value("settings", "ui_scale", 1)), 0, 2)
	settings_language = str(cfg.get_value("settings", "language", "ru"))
	settings_screen_mode = int(cfg.get_value("settings", "screen_mode", 0))
	settings_damage_numbers = bool(cfg.get_value("settings", "damage_numbers", true))
	settings_flashes = bool(cfg.get_value("settings", "flashes", true))
	gold = int(cfg.get_value("meta", "gold", 0))
	achievements = cfg.get_value("achievements", "unlocked", {})
	var saved_profile = cfg.get_value("profile", "data", {})
	if saved_profile is Dictionary:
		for key in saved_profile.keys():
			profile[key] = saved_profile[key]
	# Совместимость: забеги старого героя «mage» считаем забегами лучника.
	if profile.has("heroes") and profile["heroes"] is Dictionary and profile["heroes"].has("mage"):
		profile["heroes"]["archer"] = int(profile["heroes"].get("archer", 0)) + int(profile["heroes"]["mage"])
		profile["heroes"].erase("mage")
	meta_upgrades = cfg.get_value("meta", "upgrades", meta_upgrades)
	for def_data in meta_definitions:
		if not meta_upgrades.has(str(def_data["id"])):
			meta_upgrades[str(def_data["id"])] = 0

## Сохраняет забег, обновляет рекорды. Возвращает true, если побит любой рекорд.
func save_run(run_time: float, run_kills: int, run_level: int) -> bool:
	var is_new_record: bool = false
	if run_time > best_time:
		best_time = run_time
		is_new_record = true
	if run_kills > best_kills:
		best_kills = run_kills
		is_new_record = true
	if run_level > best_level:
		best_level = run_level
		is_new_record = true
	var entry: Dictionary = {
		"time": run_time,
		"kills": run_kills,
		"level": run_level,
		"date": Time.get_datetime_string_from_system(),
	}
	history.push_front(entry)
	while history.size() > MAX_HISTORY:
		history.pop_back()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("best", "time", best_time)
	cfg.set_value("best", "kills", best_kills)
	cfg.set_value("best", "level", best_level)
	cfg.set_value("history", "runs", history)
	cfg.set_value("settings", "character", selected_character)
	cfg.set_value("settings", "difficulty", selected_difficulty)
	cfg.set_value("settings", "map", selected_map)
	cfg.set_value("settings", "volume", settings_volume)
	cfg.set_value("settings", "quality", settings_quality)
	cfg.set_value("settings", "fps", settings_fps)
	cfg.set_value("settings", "shake", settings_shake)
	cfg.set_value("settings", "ui_scale", settings_ui_scale)
	cfg.set_value("settings", "language", settings_language)
	cfg.set_value("settings", "screen_mode", settings_screen_mode)
	cfg.set_value("settings", "damage_numbers", settings_damage_numbers)
	cfg.set_value("settings", "flashes", settings_flashes)
	cfg.set_value("meta", "gold", gold)
	cfg.set_value("meta", "upgrades", meta_upgrades)
	_apply_profile_sections(cfg)
	cfg.save(SAVE_PATH)
	return is_new_record

func format_time(sec: float) -> String:
	var total: int = int(sec)
	return "%02d:%02d" % [total / 60, total % 60]

func get_character(char_id: String) -> Dictionary:
	for char_data in characters:
		if str(char_data["id"]) == char_id:
			return char_data
	return characters[0]

func is_achievement_unlocked(achievement_id: String) -> bool:
	return bool(achievements.get(achievement_id, false))

func achievement_count() -> int:
	var count: int = 0
	for key in achievements.keys():
		if bool(achievements[key]):
			count += 1
	return count

func achievement_reward_total() -> int:
	# Сколько золота уже получено за открытые достижения.
	var total: int = 0
	for def in achievement_definitions:
		if is_achievement_unlocked(str(def["id"])):
			total += int(def["gold"])
	return total

func check_run_achievements(run_data: Dictionary) -> Array:
	# Проверяет условия достижений по текущему состоянию забега.
	# Возвращает список ТОЛЬКО что открытых достижений (для объявления в HUD).
	var kills: int = int(run_data.get("kills", 0))
	var level: int = int(run_data.get("level", 1))
	var run_time: float = float(run_data.get("time", 0.0))
	var damage_taken: int = int(run_data.get("damage_taken", 0))
	var evolutions: int = int(run_data.get("evolutions", 0))
	var spells: int = int(run_data.get("spells", 0))
	var miniboss_kills: int = int(run_data.get("miniboss_kills", 0))
	var victory: bool = bool(run_data.get("victory", false))
	var difficulty: String = str(run_data.get("difficulty", "normal"))
	for spell_id in run_data.get("spell_ids", []):
		profile["spells_seen"][str(spell_id)] = true
	var conditions: Dictionary = {
		"first_blood": kills >= 100,
		"kills500": kills >= 500,
		"kills1000": kills >= 1000,
		"survive5": run_time >= 300.0,
		"survive10": run_time >= 600.0,
		"level10": level >= 10,
		"level20": level >= 20,
		"level30": level >= 30,
		"boss_slayer": victory,
		"victory_easy": victory and difficulty == "easy",
		"victory_hard": victory and difficulty == "hard",
		"evo1": evolutions >= 1,
		"evo3": evolutions >= 3,
		"all_weapons": spells >= 4,
		"no_damage": damage_taken == 0 and run_time >= 300.0,
		"miniboss": miniboss_kills >= 1,
		"gold1000": int(profile["total_gold"]) >= 1000,
		"all_heroes": profile["heroes"].size() >= characters.size(),
		"spell_master": profile["spells_seen"].size() >= 8,
		"marathon": float(profile["total_time"]) + run_time >= 1800.0,
	}
	var newly: Array = []
	for def in achievement_definitions:
		var achievement_id: String = str(def["id"])
		if is_achievement_unlocked(achievement_id):
			continue
		if bool(conditions.get(achievement_id, false)):
			achievements[achievement_id] = true
			gold += int(def["gold"])
			profile["total_gold"] = int(profile["total_gold"]) + int(def["gold"])
			newly.append({"id": achievement_id, "name": str(def["name"]), "gold": int(def["gold"])})
	if newly.size() > 0:
		save_profile()
	return newly

func start_run() -> void:
	profile["total_runs"] = int(profile["total_runs"]) + 1
	profile["heroes"][selected_character] = int(profile["heroes"].get(selected_character, 0)) + 1
	profile["difficulties"][selected_difficulty] = int(profile["difficulties"].get(selected_difficulty, 0)) + 1
	save_profile()

func finish_run(run_time: float, run_kills: int, run_level: int, victory: bool) -> void:
	profile["total_kills"] = int(profile["total_kills"]) + run_kills
	profile["total_time"] = float(profile["total_time"]) + run_time
	profile["best_kills"] = maxi(int(profile["best_kills"]), run_kills)
	if victory:
		profile["victories"] = int(profile["victories"]) + 1
		profile["boss_kills"] = int(profile["boss_kills"]) + 1
	else:
		profile["deaths"] = int(profile["deaths"]) + 1
	save_profile()

## Имя любимого героя (для профиля).
func favorite_hero_name() -> String:
	var best_id: String = ""
	var best_runs: int = 0
	for hero_id in profile["heroes"].keys():
		if int(profile["heroes"][hero_id]) > best_runs:
			best_runs = int(profile["heroes"][hero_id])
			best_id = str(hero_id)
	if best_id == "":
		return "—"
	for char_data in characters:
		if str(char_data["id"]) == best_id:
			return "%s (%d забегов)" % [str(char_data["name"]), best_runs]
	return best_id

func set_selected_character(char_id: String) -> void:
	selected_character = char_id
	save_settings()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH) # Загружаем, чтобы не потерять рекорды
	cfg.set_value("settings", "character", selected_character)
	cfg.set_value("settings", "difficulty", selected_difficulty)
	cfg.set_value("settings", "map", selected_map)
	cfg.set_value("settings", "volume", settings_volume)
	cfg.set_value("settings", "quality", settings_quality)
	cfg.set_value("settings", "fps", settings_fps)
	cfg.set_value("settings", "shake", settings_shake)
	cfg.set_value("settings", "ui_scale", settings_ui_scale)
	cfg.set_value("settings", "language", settings_language)
	cfg.set_value("settings", "screen_mode", settings_screen_mode)
	cfg.set_value("settings", "damage_numbers", settings_damage_numbers)
	cfg.set_value("settings", "flashes", settings_flashes)
	cfg.save(SAVE_PATH)

func get_difficulty() -> Dictionary:
	if difficulty_definitions.has(selected_difficulty):
		return difficulty_definitions[selected_difficulty]
	return difficulty_definitions["normal"]

func get_map() -> Dictionary:
	for map_data in map_definitions:
		if str(map_data["id"]) == selected_map:
			return map_data
	return map_definitions[0]

func map_name() -> String:
	return Loc.t(str(get_map().get("name", "Лес")))

func map_desc() -> String:
	return Loc.t(str(get_map().get("desc", "")))

func set_map(map_id: String) -> void:
	selected_map = map_id
	save_settings()

func difficulty_value(key: String) -> float:
	return float(get_difficulty().get(key, 1.0))

func difficulty_name() -> String:
	return Loc.t(str(get_difficulty().get("name", "Нормальная")))

func difficulty_desc() -> String:
	return Loc.t(str(get_difficulty().get("desc", "")))

func set_difficulty(difficulty_id: String) -> void:
	selected_difficulty = difficulty_id
	save_settings()

func set_volume(value: float) -> void:
	settings_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()

func apply_volume() -> void:
	if settings_volume <= 0.01:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(settings_volume))

## Смена языка: сохраняем и сразу применяем.
func set_language(language_id: String) -> void:
	settings_language = "en" if language_id == "en" else "ru"
	save_settings()

func set_quality(mode_index: int) -> void:
	settings_quality = clampi(mode_index, 0, 2)
	save_settings()

## Уровень качества графики: 0 низкое, 1 среднее, 2 высокое.
const QUALITY_KEYS: Array[String] = ["Низкое", "Среднее", "Высокое"]

func quality_key() -> String:
	return QUALITY_KEYS[clampi(settings_quality, 0, 2)]

## Сколько частиц разрешено одновременно. Средний уровень = прежний бюджет (320).
func quality_max_particles() -> int:
	match settings_quality:
		0:
			return 90
		2:
			return 640
		_:
			return 320

## Потолок частиц на один взрыв (крупный взрыв босса и так больше не просит).
func quality_burst_particles() -> int:
	match settings_quality:
		0:
			return 16
		2:
			return 64
		_:
			return 40

## Потолок числа узлов-взрывов: на слабом железе меньшее число узлов дешевле.
func quality_burst_nodes() -> int:
	match settings_quality:
		0:
			return 10
		2:
			return 40
		_:
			return 24

## Цифры урона: на низком качестве их нет — экран не забивается числами.
func quality_damage_numbers() -> bool:
	return settings_quality > 0

## Яркость вспышки экрана: на низком качестве приглушена.
func quality_flash_scale() -> float:
	return 0.6 if settings_quality == 0 else 1.0

## Цифры в бою (урон и лечение): своя галочка игрока плюс бюджет качества —
## на низком качестве их нет вовсе, а выключенная галочка убирает и на среднем/высоком.
func set_damage_numbers(enabled: bool) -> void:
	settings_damage_numbers = enabled
	save_settings()

func show_floating_numbers() -> bool:
	return settings_damage_numbers and quality_damage_numbers()

## Вспышки экрана: выключены — вспышка не рисуется совсем (тряска настраивается отдельно).
func set_flashes(enabled: bool) -> void:
	settings_flashes = enabled
	save_settings()

func set_fps_counter(enabled: bool) -> void:
	settings_fps = enabled
	save_settings()

func set_ui_scale(mode_index: int) -> void:
	settings_ui_scale = clampi(mode_index, 0, 2)
	save_settings()

func set_shake(mode_index: int) -> void:
	settings_shake = clampi(mode_index, 0, 2)
	FX.clear_shake()
	save_settings()

## Множитель амплитуды тряски: 1.0 обычная, 0.45 слабая, 0.0 выключена.
func shake_factor() -> float:
	match settings_shake:
		1:
			return 0.45
		2:
			return 0.0
		_:
			return 1.0

func set_screen_mode(mode_index: int) -> void:
	settings_screen_mode = mode_index
	apply_screen_mode()
	save_settings()

func apply_screen_mode() -> void:
	# В Godot 4 нет отдельного «безрамочного» режима окна:
	# это оконный режим плюс флаг WINDOW_FLAG_BORDERLESS.
	match settings_screen_mode:
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# --- Мета-прогресс: золото и магазин ---

func add_gold(amount: int) -> void:
	# Только в памяти — на диск пишем при сохранении забега и покупке.
	gold += amount
	if amount > 0:
		profile["total_gold"] = int(profile["total_gold"]) + amount

func _apply_profile_sections(cfg: ConfigFile) -> void:
	cfg.set_value("profile", "data", profile)
	cfg.set_value("achievements", "unlocked", achievements)

## Стандартный профиль: ровно то же, что при самом первом запуске игры.
func _fresh_profile() -> Dictionary:
	return {
		"total_runs": 0,
		"total_kills": 0,
		"total_time": 0.0,
		"total_gold": 0,
		"victories": 0,
		"deaths": 0,
		"boss_kills": 0,
		"best_kills": 0,
		"heroes": {},
		"difficulties": {},
		"spells_seen": {},
	}

## Копируем файл сохранения, прежде чем что-то стирать (молча, в фоне).
func _keep_save_backup() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var src: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var data: PackedByteArray = src.get_buffer(int(src.get_length()))
	src.close()
	var dst: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_buffer(data)
	dst.close()

## Сброс только рекордов и истории забегов. Золото, прокачка, достижения и
## статистика профиля остаются — для тех, кто хочет чистую таблицу рекордов.
func reset_records() -> void:
	_keep_save_backup()
	best_time = 0.0
	best_kills = 0
	best_level = 1
	history = []
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("best", "time", 0.0)
	cfg.set_value("best", "kills", 0)
	cfg.set_value("best", "level", 1)
	cfg.set_value("history", "runs", [])
	cfg.save(SAVE_PATH)

## Полный сброс: игра как при первом запуске. Настройки (звук, экран, язык,
## качество, тряска, FPS, масштаб интерфейса) не трогаем — иначе после сброса
## игра заговорит по-английски и развернётся на весь экран.
func reset_progress() -> void:
	_keep_save_backup()
	gold = 0
	meta_upgrades = {}
	for def_data in meta_definitions:
		meta_upgrades[str(def_data["id"])] = 0
	achievements = {}
	profile = _fresh_profile()
	best_time = 0.0
	best_kills = 0
	best_level = 1
	history = []
	selected_character = "archer"
	selected_difficulty = "normal"
	selected_map = "forest"
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("best", "time", 0.0)
	cfg.set_value("best", "kills", 0)
	cfg.set_value("best", "level", 1)
	cfg.set_value("history", "runs", [])
	cfg.set_value("meta", "gold", 0)
	cfg.set_value("meta", "upgrades", meta_upgrades)
	_apply_profile_sections(cfg)
	cfg.set_value("settings", "character", selected_character)
	cfg.set_value("settings", "difficulty", selected_difficulty)
	cfg.set_value("settings", "map", selected_map)
	cfg.save(SAVE_PATH)

func save_profile() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH) # не теряем рекорды и настройки
	_apply_profile_sections(cfg)
	cfg.save(SAVE_PATH)

func get_upgrade_level(upgrade_id: String) -> int:
	return int(meta_upgrades.get(upgrade_id, 0))

func get_upgrade_def(upgrade_id: String) -> Dictionary:
	for def_data in meta_definitions:
		if str(def_data["id"]) == upgrade_id:
			return def_data
	return {}

func upgrade_cost(upgrade_id: String) -> int:
	var def_data: Dictionary = get_upgrade_def(upgrade_id)
	if def_data.is_empty():
		return -1
	var level: int = get_upgrade_level(upgrade_id)
	if level >= int(def_data["max_level"]):
		return -1 # MAX
	return int(def_data["base_cost"]) * (level + 1)

func buy_upgrade(upgrade_id: String) -> bool:
	var cost: int = upgrade_cost(upgrade_id)
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	meta_upgrades[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	save_meta()
	return true

func save_meta() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH) # Загружаем, чтобы не потерять рекорды и героя
	cfg.set_value("meta", "gold", gold)
	cfg.set_value("meta", "upgrades", meta_upgrades)
	cfg.save(SAVE_PATH)
