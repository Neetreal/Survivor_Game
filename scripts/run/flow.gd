class_name RunFlow
extends Node
## Ход забега: награды и очередь выборов, переброс, ядро эволюции, итоги и достижения.

# ── Ссылка на забег (main.gd): через неё берём игрока, HUD и время.
var m

# ── Сцены: ядро эволюции — preload один раз на старте.
const EvoCoreScene: PackedScene = preload("res://scenes/evo_core.tscn")

# ── Состояние наград: что ждёт выбора и сколько было перебросов.
var chest_reward_pending: bool = false
## Выбор открыт за ядро мини-босса: эволюция (evo) или замена (core).
## Уровень за такой выбор не тратится.
var evo_reward_pending: bool = false
var core_reward_pending: bool = false
var reroll_count: int = 0
# ── Достижения и профиль: счётчики забега и отметка «забег закрыт».
var miniboss_kills: int = 0
var achievement_timer: float = 2.0
var run_finished: bool = false

# ── Кадр прогресса: проверка достижений — раз в секунду, дёшево.
func tick(delta: float) -> void:
	achievement_timer -= delta
	if achievement_timer <= 0.0:
		achievement_timer = 1.0
		check_achievements(false)

# ── Итоги и достижения: сводка забега и проверка достижений с наградой.
func build_run_data(victory: bool) -> Dictionary:
	return {
		"kills": m.kills,
		"level": int(m.player.get("level")),
		"time": m.elapsed_time,
		"damage_taken": int(m.player.get("damage_taken")),
		"evolutions": m.player.get("evolutions").size(),
		"spells": m.player.get("unlocked_weapons").size(),
		"spell_ids": m.player.get("unlocked_weapons"),
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
		m.hud.announce(Loc.t("ДОСТИЖЕНИЕ: %s  +%d золота") % [Loc.t(str(entry["name"])), int(entry["gold"])], Color(1.0, 0.9, 0.35), 22)
	m.hud.update_gold(Records.gold)

# ── Переброс: цена растёт с каждым использованием, новый набор того же типа выбора.
func reroll_cost() -> int:
	# Первый реролл дешёвый, дальше дорожает — чтобы не спамили.
	return 10 + reroll_count * 5

func on_reroll_requested() -> void:
	if m.game_over or m.victory_shown:
		return
	var cost: int = reroll_cost()
	if Records.gold < cost:
		AudioManager.play("hit", -16.0)
		m.hud.set_reroll_hint("Не хватает золота")
		return
	Records.add_gold(-cost)
	m.hud.update_gold(Records.gold)
	reroll_count += 1
	AudioManager.play("gem", -8.0)
	# Показываем новый набор того же типа выбора.
	if m.hud.choosing_spell:
		m.hud.show_spell_choices(m.player.call("get_spell_choices"))
	elif m.hud.choosing_level5:
		# Переброс меняет и заклинания, и то, у какого заклинания поднимется урон.
		m.hud.show_level5_choices(m.player.call("get_level5_choices"))
	elif evo_reward_pending:
		m.hud.show_level_up(m.player.call("get_evolution_choices", 3), "Ядро эволюции! Выбери эволюцию:")
	elif core_reward_pending:
		m.hud.show_level_up(m.player.call("get_upgrade_choices", 3), "Ядро мини-босса: выбери награду:")
	elif chest_reward_pending:
		m.hud.show_level_up(m.player.call("get_upgrade_choices", 3), "Сундук! Выбери награду:")
	else:
		m.hud.show_level_up(m.player.call("get_upgrade_choices", 3))
	m.hud.update_reroll_cost(reroll_cost(), Records.gold)

# ── Прокачка: пауза и очередь выборов — заклинание, улучшение, сундук, ядро.
func on_leveled_up() -> void:
	AudioManager.play("levelup", -4.0)
	FX.burst(m.player.global_position, Color(1.0, 0.85, 0.2), 24, 160.0)
	get_tree().paused = true
	show_next_choice()

func show_next_choice() -> void:
	# Порядок: сначала новое заклинание (каждый 5-й уровень), потом улучшение.
	if int(m.player.get("pending_spell_choices")) > 0:
		# Пятый уровень: один выбор — два заклинания и «+50% урона» по центру.
		var lvl5: Array = m.player.call("get_level5_choices")
		# Пустое окно выбора держало бы игру на паузе.
		if lvl5.is_empty():
			m.player.set("pending_spell_choices", 0)
		else:
			m.hud.show_level5_choices(lvl5)
			m.hud.update_reroll_cost(reroll_cost(), Records.gold)
			return
	if int(m.player.get("pending_level_ups")) > 0:
		m.hud.show_level_up(m.player.call("get_upgrade_choices", 3))
	else:
		m.hud.hide_level_up()
		get_tree().paused = false
		return
	m.hud.update_reroll_cost(reroll_cost(), Records.gold)

func on_chest_opened() -> void:
	if m.game_over:
		return
	AudioManager.play("chest", -4.0)
	chest_reward_pending = true
	get_tree().paused = true
	m.hud.show_level_up(m.player.call("get_upgrade_choices", 3), "Сундук! Выбери награду:")
	m.hud.update_reroll_cost(reroll_cost(), Records.gold)

## Усиление урона из панели 5-го уровня: уровень уже израсходован на этот выбор.
func on_level5_chosen(card_id: String) -> void:
	m.player.call("apply_upgrade", card_id)
	m.player.set("pending_spell_choices", maxi(0, int(m.player.get("pending_spell_choices")) - 1))
	show_next_choice()

func on_spell_chosen(spell_id: String) -> void:
	m.player.call("unlock_spell", spell_id)
	m.player.set("pending_spell_choices", int(m.player.get("pending_spell_choices")) - 1)
	show_next_choice()

func on_upgrade_chosen(upgrade_id: String) -> void:
	m.player.call("apply_upgrade", upgrade_id)
	if upgrade_id.begins_with("evo_"):
		var evo_name: String = str(m.player.get("evolution_names").get(upgrade_id, "Эволюция"))
		m.hud.announce(Loc.t("ЭВОЛЮЦИЯ: %s!") % Loc.t(evo_name), Color(1.0, 0.85, 0.25))
		m.hud.update_gold(Records.gold)
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
	m.player.set("pending_level_ups", int(m.player.get("pending_level_ups")) - 1)
	show_next_choice()

# ── Ядро эволюции: падает с мини-босса, при подборе — пауза и выбор награды.
func spawn_evo_core(at_position: Vector2) -> void:
	var core = EvoCoreScene.instantiate()
	core.configure(at_position)
	m.add_child(core)
	m.hud.announce(Loc.t("Ядро эволюции! Подбери его"), Color(1.0, 0.8, 0.35), 22)

## Ядро подобрано: пауза и выбор. Есть готовые эволюции — показываем их,
## иначе даём обычное улучшение, чтобы награда за мини-босса не была пустой.
func on_evo_core_collected() -> void:
	if m.game_over:
		return
	var evolutions: Array = m.player.call("get_evolution_choices", 3)
	get_tree().paused = true
	if not evolutions.is_empty():
		evo_reward_pending = true
		m.hud.show_level_up(evolutions, "Ядро эволюции! Выбери эволюцию:")
	else:
		core_reward_pending = true
		m.hud.show_level_up(m.player.call("get_upgrade_choices", 3), "Ядро мини-босса: выбери награду:")
	m.hud.update_reroll_cost(reroll_cost(), Records.gold)

# ── Финал забега: победа, выход в бесконечный режим, поражение, рестарт и выход в меню.
func trigger_victory() -> void:
	m.victory_shown = true
	AudioManager.play("victory", -2.0)
	AudioManager.stop_music(1.2)
	FX.shake(0.9, 1.4)
	FX.flash(Color(1.0, 0.9, 0.4), 0.35, 0.8)
	Records.add_gold(100) # Бонус за победу над боссом
	m.hud.update_gold(Records.gold)
	if not run_finished:
		run_finished = true
		Records.finish_run(m.elapsed_time, m.kills, int(m.player.get("level")), true)
	check_achievements(true)
	m.hud.show_victory(m.elapsed_time, m.kills, int(m.player.get("level")))
	get_tree().paused = true

func on_continue_endless() -> void:
	m.hud.hide_victory()
	get_tree().paused = false

func on_victory_menu() -> void:
	# Победоносный забег сохраняем в рекорды при выходе в меню.
	Records.save_run(m.elapsed_time, m.kills, int(m.player.get("level")))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func on_player_died() -> void:
	if m.game_over:
		return
	m.game_over = true
	if not run_finished:
		run_finished = true
		Records.finish_run(m.elapsed_time, m.kills, int(m.player.get("level")), false)
	check_achievements(false)
	AudioManager.play("gameover", -2.0)
	AudioManager.stop_music(1.5)
	FX.shake(1.0, 1.2)
	FX.flash(Color(0.6, 0.0, 0.0), 0.4, 0.9)
	# Сохраняем забег в рекорды (автозагрузка Records)
	var is_new_record: bool = Records.save_run(m.elapsed_time, m.kills, int(m.player.get("level")))
	m.hud.show_game_over(m.elapsed_time, m.kills, int(m.player.get("level")), is_new_record)
	get_tree().paused = true

func on_restart_requested() -> void:
	# Выход из забега без смерти тоже учитываем в профиле.
	if not run_finished:
		run_finished = true
		check_achievements(false)
		Records.finish_run(m.elapsed_time, m.kills, int(m.player.get("level")), false)
		Records.save_run(m.elapsed_time, m.kills, int(m.player.get("level")))
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_menu_requested() -> void:
	if not run_finished:
		run_finished = true
		check_achievements(false)
		Records.finish_run(m.elapsed_time, m.kills, int(m.player.get("level")), false)
		Records.save_run(m.elapsed_time, m.kills, int(m.player.get("level")))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
