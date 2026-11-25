extends Area2D
## «Ядро эволюции» — дроп мини-босса.
##
## Мини-боссы перестали быть просто «ещё одним жирным врагом»: убил — подобрал ядро —
## выбрал эволюцию оружия. Ядро не исчезает со временем и притягивается к игроку
## с большего расстояния, чем кристаллы опыта, чтобы его нельзя было потерять в толпе.
##
## Кто именно награждает игрока, решает main.gd (`on_evo_core_collected`): если готовых
## эволюций нет, панель покажет обычные улучшения. Ядро о награде ничего не знает.

## Притяжение включается не по всему радиусу магнита, иначе ядро «телепортируется»
## в игрока в момент смерти мини-босса и награда не читается. Магнит учитывается,
## но не больше этого предела: ядро должно полежать на земле, пока к нему не подойдёшь.
const PULL_CAP: float = 130.0
## Небольшой запас сверх магнита, чтобы ядро не «залипало» на самой границе.
const PULL_BONUS: float = 20.0
## Скорость притяжения на самой границе радиуса и у игрока.
const PULL_SLOW: float = 300.0
const PULL_FAST: float = 780.0
## На таком расстоянии ядро подбирается само, даже если магнит отключён.
const PICKUP_DISTANCE: float = 26.0

var pending_position: Vector2 = Vector2.ZERO
var base_y: float = 0.0
var time: float = 0.0
var player = null
var glow: Sprite2D = null

@onready var visual: Polygon2D = $Visual
@onready var body: Sprite2D = $Body

func configure(spawn_position: Vector2) -> void:
	pending_position = spawn_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("evo_cores")
	global_position = pending_position
	base_y = pending_position.y
	# Нет спрайта — остаётся ромб, но всё равно заметный: золотая заливка + свечение.
	FxVisual.use_sprite(body, visual, "fx_evo_core")
	glow = FxVisual.add_glow(self, Color(1.0, 0.78, 0.35), 150.0, 0.6)
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	time += delta
	# Покачивание и пульсация: ядро видно и в толпе, и на тёмной арене.
	var pulse: float = 1.0 + sin(time * 5.0) * 0.09
	visual.scale = Vector2.ONE * pulse
	body.scale = Vector2.ONE * pulse
	body.rotation = time * 1.4
	if glow != null:
		glow.modulate.a = 0.45 + sin(time * 3.4) * 0.15
	if player != null and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		var dist: float = to_player.length()
		var magnet: float = minf(float(player.get("magnet_radius")), PULL_CAP) + PULL_BONUS
		if dist <= PICKUP_DISTANCE:
			collect()
			return
		if dist < magnet and dist > 1.0:
			var closeness: float = 1.0 - dist / magnet
			var pull_speed: float = PULL_SLOW + closeness * (PULL_FAST - PULL_SLOW)
			global_position += to_player.normalized() * pull_speed * delta
			return
	# Притяжения нет — просто висит и покачивается.
	global_position.y = base_y + sin(time * 2.0) * 4.0

func collect() -> void:
	if is_queued_for_deletion():
		return
	AudioManager.play("chest", -4.0)
	FX.flash(Color(1.0, 0.8, 0.35), 0.16, 0.3)
	FX.burst(global_position, Color(1.0, 0.8, 0.35), 22, 190.0)
	var game = get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_evo_core_collected"):
		game.call("on_evo_core_collected")
	queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		collect()
