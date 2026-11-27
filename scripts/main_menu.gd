extends Control
## Главное меню: кнопки в центре и окна меню (каждое — свой скрипт в scripts/menu).

# ── Кнопки главного экрана, подпись рекорда и подложка под окнами.
@onready var play_button: Button = $Center/VBox/PlayButton
@onready var records_button: Button = $Center/VBox/RecordsButton
@onready var shop_button: Button = $Center/VBox/ShopButton
@onready var profile_button: Button = $Center/VBox/ProfileButton
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var best_label: Label = $Center/VBox/BestLabel
@onready var menu_center: CenterContainer = $Center
@onready var dimmer: ColorRect = $Dimmer

# ── Окна меню: диспетчер их только показывает и прячет, содержимым заняты сами окна.
@onready var records_panel: MenuRecords = $RecordsPanel
@onready var play_panel: MenuPlay = $CharacterPanel
@onready var shop_panel: MenuShop = $ShopPanel
@onready var profile_panel: MenuProfile = $ProfilePanel
@onready var achievements_panel: MenuAchievements = $AchievementsPanel
@onready var settings_panel: MenuSettings = $SettingsPanel
@onready var confirm_panel: MenuConfirm = $ConfirmPanel

## Все окна меню. Видимым может быть только одно, иначе нижнее просвечивало бы.
var all_panels: Array[MenuPanel] = []

# ── Старт меню: подписка на кнопки, перевод, настройки, музыка, фокус для геймпада.
func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	records_button.pressed.connect(_on_records_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Окна получают ссылку на диспетчер и ждут первого открытия скрытыми.
	all_panels = [records_panel, play_panel, shop_panel, profile_panel, achievements_panel, settings_panel, confirm_panel]
	for panel in all_panels:
		panel.menu = self
		panel.visible = false
	dimmer.visible = false
	# Локализация: переводим подписи сцены (русский — исходный текст).
	Loc.translate_tree(self)
	# Настройки рисуем после перевода, иначе маркеры ▶ затрутся текстом из сцены.
	settings_panel.refresh()
	# Геймпад: фокус сразу на первой кнопке, дальше — крестовина/стик и A.
	play_button.grab_focus()
	AudioManager.play_music("menu")
	refresh_best_label()
	# Масштаб интерфейса — в самом конце, когда все окна уже собраны.
	UIScale.apply(self)
	# При изменении размера окна панели подгоняем заново.
	get_viewport().size_changed.connect(_on_viewport_resized)

# ── Показ окон: открыто ровно одно, меню под ним скрыто, панель подогнана под экран.
func show_panel(target: MenuPanel) -> void:
	for panel in all_panels:
		panel.visible = (panel == target)
	menu_center.visible = false
	dimmer.visible = target != null
	if target == null:
		return
	# Сначала окно наполняется данными, потом подгоняем размер: списки могли измениться.
	target.open()
	UIScale.fit_panel(target, get_viewport().get_visible_rect().size)

# ── Закрыть все окна и вернуться к списку кнопок главного меню.
func close_panels() -> void:
	for panel in all_panels:
		panel.visible = false
	menu_center.visible = true
	dimmer.visible = false
	play_button.grab_focus()

# ── Esc и B: сначала закрывают окно подтверждения, потом текущее окно меню.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Esc/B поверх окна подтверждения закрывает только его — настройки остаются.
	if confirm_panel.visible:
		AudioManager.play("click", -8.0)
		confirm_panel.cancel()
	elif not menu_center.visible:
		AudioManager.play("click", -8.0)
		close_panels()
	else:
		return
	get_viewport().set_input_as_handled()

# ── Строка рекорда внизу главного меню.
func refresh_best_label() -> void:
	if Records.best_time > 0.0:
		best_label.text = Loc.t("Рекорд: %s • Убийств: %d • Уровень: %d") % [Records.format_time(Records.best_time), Records.best_kills, Records.best_level]
	else:
		best_label.text = Loc.t("Рекордов пока нет — сыграй первый забег!")

# ── Кнопки главного экрана: открыть нужное окно.
func _on_play_pressed() -> void:
	AudioManager.play("click", -8.0)
	show_panel(play_panel)

func _on_records_pressed() -> void:
	AudioManager.play("click", -8.0)
	show_panel(records_panel)

func _on_shop_pressed() -> void:
	AudioManager.play("click", -8.0)
	show_panel(shop_panel)

func _on_profile_pressed() -> void:
	AudioManager.play("click", -8.0)
	show_panel(profile_panel)

func _on_settings_pressed() -> void:
	AudioManager.play("click", -8.0)
	show_panel(settings_panel)

func _on_quit_pressed() -> void:
	AudioManager.play("click", -8.0)
	get_tree().quit()

# ── Изменение размера окна: подогнать видимое окно заново.
func _on_viewport_resized() -> void:
	for panel in all_panels:
		if panel.visible:
			UIScale.fit_panel(panel, get_viewport().get_visible_rect().size)
