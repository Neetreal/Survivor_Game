extends Area2D
## Бумеранг: улетает от игрока и возвращается, бьёт врагов в обе стороны.

var direction: Vector2 = Vector2.RIGHT
var damage: int = 14
var speed: float = 430.0
var max_out_distance: float = 210.0
var pending_position: Vector2 = Vector2.ZERO
var traveled: float = 0.0
var returning: bool = false
var life: float = 3.0

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(angle: float, dmg: int, spd: float, out_distance: float, spawn_position: Vector2) -> void:
	direction = Vector2.from_angle(angle)
	damage = dmg
	speed = spd
	max_out_distance = out_distance
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	global_position = pending_position
	area_entered.connect(_on_area_entered)
	FxVisual.use_sprite(body, visual, "fx_boomerang")
	FxVisual.add_trail(self, Color(1.0, 0.72, 0.45), 5.0, 0.16)
	FX.burst(global_position, Color(1.0, 0.75, 0.45), 3, 70.0)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	visual.rotation += 12.0 * delta
	body.rotation += 12.0 * delta
	if not returning:
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_out_distance:
			returning = true
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			queue_free()
			return
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() < 26.0:
			queue_free() # Пойман игроком
			return
		direction = to_player.normalized()
		global_position += direction * speed * delta
	for area in get_overlapping_areas():
		_on_area_entered(area)

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	if float(area.get("boomerang_cooldown")) > 0.0:
		return
	area.set("boomerang_cooldown", 0.35)
	area.call("take_damage", damage, global_position, "boomerang")
	FX.burst(area.global_position, Color(1.0, 0.78, 0.45), 3, 80.0)
