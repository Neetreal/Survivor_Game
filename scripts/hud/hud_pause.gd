class_name HudPause
extends HudWindow
## Окно паузы: краткий отчёт о забеге, управление и полная сборка.

# ── Узлы окна: строка отчёта, подсказки управления, сборка и кнопки.
@onready var stats_label: Label = $VBox/PauseStats
@onready var controls_label: Label = $VBox/ControlsLabel
@onready var build_stats: Label = $VBox/BuildScroll/BuildStats
@onready var continue_button: Button = $VBox/PauseContinueButton
@onready var restart_button: Button = $VBox/PauseRestartButton
@onready var menu_button: Button = $VBox/PauseMenuButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

# ── Отчёт в паузе: время, убийства, уровень, управление и полная сборка.
func show_report(elapsed: float, kills: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var level: int = int(player.get("level")) if player != null else 1
	var total_seconds: int = int(elapsed)
	stats_label.text = Loc.t("Время: %02d:%02d   •   Убийств: %d   •   Уровень: %d") % [total_seconds / 60, total_seconds % 60, kills, level]
	# Управление — только здесь, в бою подсказок нет.
	controls_label.text = "\n".join(PackedStringArray([
		Loc.t("Управление"),
		Loc.t("Движение — WASD / стрелки / стик"),
		Loc.t("Пауза — Esc / P / Start"),
		Loc.t("Выбор — стрелки / крестовина, подтвердить — Enter / A, назад — Esc / B"),
	]))
	# Полный список только того, что реально есть у игрока.
	if player != null and player.has_method("build_report"):
		build_stats.text = str(player.call("build_report"))
	else:
		build_stats.text = "—"
	# Подгоняем после заполнения текста: отчёт о сборке меняет высоту панели.
	fit()
	# Фокус на первую кнопку — чтобы геймпад сразу мог продолжить игру.
	continue_button.grab_focus()

# ── Кнопки окна: продолжить, начать заново, выйти в меню.
func _on_continue_pressed() -> void:
	click()
	hud.close_pause()

func _on_restart_pressed() -> void:
	click()
	hud.restart_requested.emit()

func _on_menu_pressed() -> void:
	click()
	hud.menu_requested.emit()
