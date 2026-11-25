extends Area2D
## Клинок на орбите вокруг игрока.

var damage: int = 10

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func _ready() -> void:
	FxVisual.use_sprite(body, visual, "fx_blade")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	area_entered.connect(_on_area_entered)

func _on_area_entered(area) -> void:
	if not area.is_in_group("enemies"):
		return
	if float(area.get("orbit_cooldown")) > 0.0:
		return
	area.set("orbit_cooldown", 0.45)
	if area.has_method("take_damage"):
		area.call("take_damage", damage, global_position, "orbit")
