class_name MenuPlay
extends MenuPanel
## Окно «Играть»: герой, сложность, карта и кнопка «В бой».

# ── Узлы окна: выбор сложности и карты, описание выбора, список героев.
@onready var easy_button: Button = $VBox/DifficultyBox/EasyButton
@onready var normal_button: Button = $VBox/DifficultyBox/NormalButton
@onready var hard_button: Button = $VBox/DifficultyBox/HardButton
@onready var forest_button: Button = $VBox/MapBox/ForestButton
@onready var bog_button: Button = $VBox/MapBox/BogButton
@onready var arena_button: Button = $VBox/MapBox/ArenaButton
@onready var difficulty_desc: Label = $VBox/DifficultyDesc
@onready var start_button: Button = $VBox/StartButton
@onready var back_button: Button = $VBox/BackButton
@onready var character_list: VBoxContainer = $VBox/Scroll/CharacterList

# ── Подписка на кнопки окна.
func _ready() -> void:
	back_button.pressed.connect(back)
	start_button.pressed.connect(_on_start_pressed)
	easy_button.pressed.connect(_on_difficulty_selected.bind("easy"))
	normal_button.pressed.connect(_on_difficulty_selected.bind("normal"))
	hard_button.pressed.connect(_on_difficulty_selected.bind("hard"))
	forest_button.pressed.connect(_on_map_selected.bind("forest"))
	bog_button.pressed.connect(_on_map_selected.bind("bog"))
	arena_button.pressed.connect(_on_map_selected.bind("arena"))

# ── Открытие окна: собрать список героев, отметить выбор, фокус на «В бой».
func open() -> void:
	build_character_list()
	refresh_difficulty_buttons()
	start_button.grab_focus()

# ── Выбор сложности и карты: маркер ▶ у текущего варианта и подпись под ними.
func refresh_difficulty_buttons() -> void:
	var easy_name: String = Loc.t(str(Records.difficulty_definitions["easy"]["name"]))
	var normal_name: String = Loc.t(str(Records.difficulty_definitions["normal"]["name"]))
	var hard_name: String = Loc.t(str(Records.difficulty_definitions["hard"]["name"]))
	choice(easy_button, easy_name, Records.selected_difficulty == "easy")
	choice(normal_button, normal_name, Records.selected_difficulty == "normal")
	choice(hard_button, hard_name, Records.selected_difficulty == "hard")
	start_button.text = Loc.t("В бой! (%s)") % Records.difficulty_name()
	refresh_map_buttons()
	refresh_choice_info()

func refresh_map_buttons() -> void:
	choice(forest_button, Loc.t("Лес"), Records.selected_map == "forest")
	choice(bog_button, Loc.t("Топкие болота"), Records.selected_map == "bog")
	choice(arena_button, Loc.t("Арена"), Records.selected_map == "arena")

func refresh_choice_info() -> void:
	difficulty_desc.text = Loc.t("%s\nКарта «%s»: %s") % [Records.difficulty_desc(), Records.map_name(), Records.map_desc()]

func _on_map_selected(map_id: String) -> void:
	click()
	Records.set_map(map_id)
	refresh_map_buttons()
	refresh_choice_info()

func _on_difficulty_selected(difficulty_id: String) -> void:
	click()
	Records.set_difficulty(difficulty_id)
	refresh_difficulty_buttons()

# ── Старт забега: переход в главную сцену.
func _on_start_pressed() -> void:
	click()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ── Список героев: кнопка на героя с его заклинанием и описанием.
func build_character_list() -> void:
	clear_list(character_list)
	for char_data in Records.characters:
		var char_id: String = str(char_data["id"])
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_font_size_override("font_size", 13)
		var marker: String = "▶ " if char_id == Records.selected_character else ""
		button.text = "%s%s — %s\n%s" % [marker, Loc.t(str(char_data["name"])), Loc.t(str(char_data["spell_name"])), Loc.t(str(char_data["desc"]))]
		button.pressed.connect(_on_character_selected.bind(char_id))
		character_list.add_child(button)
	UIScale.apply(character_list)

func _on_character_selected(char_id: String) -> void:
	click()
	Records.set_selected_character(char_id)
	build_character_list()
