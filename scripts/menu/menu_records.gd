class_name MenuRecords
extends MenuPanel
## Окно рекордов: лучший забег и история последних.

# ── Узлы окна: две подписи с текстом.
@onready var best_stats_label: Label = $VBox/BestStatsLabel
@onready var history_label: Label = $VBox/HistoryLabel

# ── Подписка на кнопку «Назад».
func _ready() -> void:
	$VBox/BackButton.pressed.connect(back)

# ── Открытие окна: пересобрать тексты и отдать фокус.
func open() -> void:
	build()
	$VBox/BackButton.grab_focus()

# ── Тексты окна: лучший забег и последние забеги (дата, время, убийства, уровень).
func build() -> void:
	if Records.best_time > 0.0:
		best_stats_label.text = Loc.t("Лучшее время: %s\nБольше всего убийств: %d\nМаксимальный уровень: %d") % [Records.format_time(Records.best_time), Records.best_kills, Records.best_level]
	else:
		best_stats_label.text = Loc.t("Рекордов пока нет.\nСыграй забег — и возвращайся сюда!")
	if Records.history.is_empty():
		history_label.text = Loc.t("Последние забеги:\n— пока пусто —")
	else:
		var text: String = Loc.t("Последние забеги:")
		for entry in Records.history:
			var date_str: String = str(entry.get("date", ""))
			if date_str.length() >= 16:
				date_str = date_str.substr(0, 10) + " " + date_str.substr(11, 5)
			text += Loc.t("\n%s — %s • Убийств: %d • Уровень: %d") % [date_str, Records.format_time(float(entry.get("time", 0.0))), int(entry.get("kills", 0)), int(entry.get("level", 1))]
		history_label.text = text
