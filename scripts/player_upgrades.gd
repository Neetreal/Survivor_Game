extends Node
class_name PlayerUpgrades
## Прокачка игрока: пул карточек уровня, пассивки, эволюции, применение улучшений
## и отчёт о сборке для экрана паузы.
##
## Вынесено из player.gd (фаза B2). Узел — дочерний к игроку, ссылка на хозяина в `p`.
## Статы по-прежнему живут в player.gd: здесь они читаются и пишутся через `p.get()/p.set()`
## по имени — на этом же построена таблица «op/value» из данных оружия.
## Имена методов сохранены прежними, чтобы player.gd мог отдавать их наружу тонкими обёртками.

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

## Хозяин: игрок. Ставится из player.gd в _ready.
var p = null

# ── Выбор улучшений: карточки уровня и эволюции за ядро мини-босса.
## Карточки на экране прокачки: пул собирается из данных (см. UpgradePool).
## Эволюций здесь больше нет — их выдаёт мини-босс, см. get_evolution_choices().
func get_upgrade_choices(count: int) -> Array:
	var pool: Array = UpgradePool.build(p)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

## Эволюции, доступные за ядро мини-босса. Пустой список — игрок получит обычные улучшения.
func get_evolution_choices(count: int = 3) -> Array:
	var available: Array = get_available_evolutions()
	available.shuffle()
	return available.slice(0, mini(count, available.size()))

## Доступные эволюции считаются из данных оружия (см. UpgradePool).
func get_available_evolutions() -> Array:
	return UpgradePool.available_evolutions(p)

# ── Заклинания: открытие новых и карточки выбора (в отчёте нужны все названия).
## Все заклинания без фильтра «чего ещё нет» — нужно для названий в отчёте.
func get_spell_choices_all() -> Array:
	return WeaponData.all_titles()

## Короткая сводка по оружию — формат и поля берутся из WeaponData.
func weapon_details(weapon_id: String) -> String:
	return WeaponData.details(p, weapon_id)

func get_spell_choices() -> Array:
	var remaining: Array = []
	for def in WeaponData.LIST:
		if not p.unlocked_weapons.has(str(def["id"])):
			remaining.append({"id": str(def["id"]), "title": str(def["title"]), "desc": str(def["desc"])})
	# Заклинаний больше, чем слотов (4) — показываем случайные 3.
	remaining.shuffle()
	return remaining.slice(0, mini(3, remaining.size()))

func unlock_spell(spell_id: String) -> void:
	if not p.unlocked_weapons.has(spell_id):
		p.unlocked_weapons.append(spell_id)
	if spell_id == "orbit":
		p.weapons.rebuild_orbit_blades()
	p.emit_stats_changed()

# ── Урон заклинаний: чтение, подъём на 50% и готовая карточка «+50% урону».
## Урон конкретного заклинания «как есть» (без общего множителя damage_mult).
func weapon_damage(weapon_id: String) -> int:
	var stat: String = str(WEAPON_DAMAGE_VARS.get(weapon_id, ""))
	if stat == "":
		return 0
	return int(p.get(stat))

## Поднять урон одного заклинания на LEVEL5_DAMAGE_BONUS (по умолчанию +50%).
func boost_weapon_damage(weapon_id: String) -> Dictionary:
	var stat: String = str(WEAPON_DAMAGE_VARS.get(weapon_id, ""))
	if stat == "":
		return {}
	var before: int = int(p.get(stat))
	# Минимум +1, иначе у слабых заклинаний бонус терялся в округлении.
	var after: int = maxi(before + 1, int(round(float(before) * LEVEL5_DAMAGE_BONUS)))
	p.set(stat, after)
	if weapon_id == "orbit":
		p.weapons.refresh_orbit_damage()
	elif weapon_id == "saw":
		pass # урон пилы передаётся при каждом спавне
	p.emit_stats_changed()
	return {"weapon": weapon_id, "before": before, "after": after}

## Случайное из открытых заклинаний, у которого есть переменная урона.
func random_boost_weapon() -> String:
	var candidates: Array = []
	for weapon_raw in p.unlocked_weapons:
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
	p.emit_hp_changed()
	p.emit_stats_changed()

## Универсальное применение улучшения по описанию из данных.
## op: add_int | mul_int | mul_float | mul_cooldown | sub_clamped | add_float | max_hp | heal
func _apply_stat_upgrade(entry: Dictionary) -> void:
	var op: String = str(entry.get("op", ""))
	var value: float = float(entry.get("value", 0.0))
	var stat: String = str(entry.get("stat", ""))
	match op:
		"add_int":
			var grown: int = int(p.get(stat)) + int(value)
			# Предел карты соблюдаем и при прямом применении, а не только в пуле.
			if entry.has("cap"):
				grown = mini(grown, int(entry["cap"]))
			p.set(stat, grown)
		"mul_int":
			p.set(stat, int(ceil(float(p.get(stat)) * value)))
		"mul_float":
			p.set(stat, float(p.get(stat)) * value)
		"mul_cooldown":
			p.set(stat, maxf(float(entry.get("min", 0.2)), float(p.get(stat)) * value))
		"sub_clamped":
			p.set(stat, maxf(float(entry.get("min", 0.0)), float(p.get(stat)) - value))
		"add_float":
			p.set(stat, float(p.get(stat)) + value)
		"set_int":
			p.set(stat, int(value))
		"set_float":
			p.set(stat, value)
		"max_hp":
			p.max_hp += int(value)
			p.heal(int(value))
		"heal":
			p.heal(int(value))
	if entry.has("after"):
		_run_weapon_hook(str(entry["after"]))

## Пересчёт производных значений после смены статы (клинки держат урон у себя).
func _run_weapon_hook(hook: String) -> void:
	match hook:
		"orbit_damage":
			p.weapons.refresh_orbit_damage()
		"orbit_rebuild":
			p.weapons.rebuild_orbit_blades()
		"orbit_size":
			p.weapons.apply_orbit_size()

# ── Пассивки и эволюции: выдача уровня пассивки и разблокировка эволюции оружия.
func apply_passive(passive_id: String) -> void:
	var def: Dictionary = PassiveData.by_id(passive_id)
	if def.is_empty():
		return
	var lvl: int = p.passive_level(passive_id)
	if lvl >= int(def["max"]):
		return
	p.passive_levels[passive_id] = lvl + 1
	_apply_stat_upgrade(def)
	AudioManager.play("levelup", -14.0)
	p.emit_hp_changed()
	p.emit_stats_changed()

func unlock_evolution(evo_id: String) -> void:
	if p.evolutions.has(evo_id):
		return
	p.evolutions.append(evo_id)
	# Постоянные бонусы берутся из данных; ситуативные эффекты
	# (лечение от новы, метеор, заморозка) проверяются через has_evo().
	for entry in WeaponData.evolution_effects(evo_id):
		_apply_stat_upgrade(entry)
	AudioManager.play("victory", -12.0)
	FX.burst(p.global_position, Color(1.0, 0.9, 0.4), 30, 180.0)
	p.emit_stats_changed()

# ── Отчёт для паузы: герой, оружие, пассивки, эволюции одним текстом.
func build_report() -> String:
	var lines: Array = []
	var char_data: Dictionary = Records.get_character(Records.selected_character)
	lines.append(Loc.t("ГЕРОЙ — %s") % Loc.t(str(char_data.get("name", "?"))))
	lines.append(Loc.t("HP %d / %d   •   Броня %d   •   Скорость %d") % [p.hp, p.max_hp, p.armor, int(p.speed)])
	lines.append(Loc.t("Урон оружия ×%.2f   •   Площадь ×%.2f   •   Опыт ×%.2f   •   Магнит %d") % [p.damage_mult, p.area_mult, p.xp_multiplier, int(p.magnet_radius)])
	lines.append("")
	var weapon_names: Dictionary = {}
	for spell in get_spell_choices_all():
		weapon_names[str(spell["id"])] = str(spell["title"])
	lines.append(Loc.t("ОРУЖИЕ (%d)") % p.unlocked_weapons.size())
	for weapon_id_raw in p.unlocked_weapons:
		var weapon_id: String = str(weapon_id_raw)
		var weapon_name: String = Loc.t(str(weapon_names.get(weapon_id, weapon_id)))
		lines.append("• %s — %s" % [weapon_name, weapon_details(weapon_id)])
	lines.append("")
	var owned_passives: Array = []
	for passive_def in p.passive_definitions:
		var pid: String = str(passive_def["id"])
		var lvl: int = p.passive_level(pid)
		if lvl > 0:
			owned_passives.append("• %s %d/%d — %s" % [Loc.t(str(passive_def["name"])), lvl, int(passive_def["max"]), Loc.t(str(passive_def["desc"]))])
	if owned_passives.size() > 0:
		lines.append(Loc.t("ПАССИВКИ (%d)") % owned_passives.size())
		lines.append_array(owned_passives)
		lines.append("")
	if p.evolutions.size() > 0:
		lines.append(Loc.t("ЭВОЛЮЦИИ (%d)") % p.evolutions.size())
		for evo_id_raw in p.evolutions:
			lines.append("• %s" % Loc.t(str(p.evolution_names.get(str(evo_id_raw), str(evo_id_raw)))))
	return "\n".join(PackedStringArray(lines))
