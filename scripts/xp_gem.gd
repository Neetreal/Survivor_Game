extends Area2D
## Кристалл опыта: притягивается к игроку и даёт опыт.
## Тиры по ценности: 1-4 малый (голубой), 5-19 средний (зелёный),
## 20-49 большой (фиолетовый), 50+ огромный (золотой).
## Близкие кристаллы со временем сливаются в один более ценный —
## так куча мелких превращается в один крупный и не нагружает игру.

const MERGE_RADIUS: float = 42.0
const MERGE_INTERVAL: float = 0.5

var gem_value: int = 1
var pending_position: Vector2 = Vector2.ZERO
var player = null
var merge_timer: float = 0.0
var merging: bool = false

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(value: int, spawn_position: Vector2) -> void:
	gem_value = value
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("gems")
	global_position = pending_position
	# Спрайт кристалла почти бесцветный — тир задаётся тинтом (см. apply_tier_visuals).
	FxVisual.use_sprite(body, visual, "fx_gem")
	apply_tier_visuals()
	merge_timer = randf_range(0.4, 1.0) # Разброс таймеров, чтобы не все проверяли в один кадр
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func apply_tier_visuals() -> void:
	# Тир задаётся размером и цветом; цвета берутся из Palette — с включённой
	# палитрой для дальтоников они уходят в бело-синюю гамму.
	if gem_value >= 50:
		scale = Vector2(2.1, 2.1)
	elif gem_value >= 20:
		scale = Vector2(1.7, 1.7)
	elif gem_value >= 5:
		scale = Vector2(1.35, 1.35)
	else:
		scale = Vector2(1.0, 1.0)
	FxVisual.set_color(body, visual, Palette.gem(gem_value))

func _physics_process(delta: float) -> void:
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		var dist: float = to_player.length()
		var magnet: float = float(player.get("magnet_radius"))
		if dist < magnet and dist > 1.0:
			var pull_speed: float = 260.0 + (1.0 - dist / magnet) * 500.0
			global_position += to_player.normalized() * pull_speed * delta
		elif dist <= 22.0:
			collect()
	if is_queued_for_deletion():
		return
	merge_timer -= delta
	if merge_timer <= 0.0:
		merge_timer = MERGE_INTERVAL
		try_merge()

func try_merge() -> void:
	# Поглощаем одного соседа за проверку — следующее слияние через интервал.
	# Так большая куча кристаллов превращается в один крупный постепенно и без лагов.
	if merging or is_queued_for_deletion():
		return
	for other in get_tree().get_nodes_in_group("gems"):
		if other == self or other.is_queued_for_deletion():
			continue
		if bool(other.get("merging")):
			continue
		if global_position.distance_squared_to(other.global_position) <= MERGE_RADIUS * MERGE_RADIUS:
			merging = true
			other.set("merging", true)
			gem_value += int(other.get("gem_value"))
			apply_tier_visuals()
			other.queue_free()
			return

func collect() -> void:
	AudioManager.play("gem", -12.0)
	FX.burst(global_position, Palette.gem_burst(), 5, 70.0)
	if player != null and player.has_method("add_xp"):
		player.call("add_xp", gem_value)
	queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		collect()
