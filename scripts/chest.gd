extends Area2D
## Сундук с элитного врага: игрок касается его — и получает
## бесплатное улучшение на выбор (то же меню, что при повышении уровня).

var pending_position: Vector2 = Vector2.ZERO
var base_y: float = 0.0
var time: float = 0.0

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(spawn_position: Vector2) -> void:
	pending_position = spawn_position

func _ready() -> void:
	FxVisual.use_sprite(body, visual, "fx_chest")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	base_y = pending_position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time += delta
	# Лёгкое покачивание, чтобы сундук было видно в толпе.
	var pulse: float = 1.0 + sin(time * 4.0) * 0.07
	visual.scale = Vector2.ONE * pulse
	body.scale = Vector2.ONE * pulse
	global_position.y = base_y + sin(time * 2.0) * 3.0

func collect() -> void:
	FX.flash(Color(1.0, 0.85, 0.3), 0.18, 0.35)
	var game = get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_chest_opened"):
		game.call("on_chest_opened")
	queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		collect()
