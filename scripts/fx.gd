extends Node
## Помощник эффектов (автозагрузка FX): частицы, тряска камеры,
## вспышка экрана и короткий hit-stop («заморозка» на удар).

const BurstScene: PackedScene = preload("res://scenes/particle_burst.tscn")

## Бюджет частиц. Взрывы не создают узлы на каждый вызов: узлы берутся из пула,
## а общее число одновременно живых частиц ограничено — толпа крупных врагов,
## умирающая в один кадр, больше не превращается в слайд-шоу.
## Сами лимиты зависят от настройки «Качество графики» (Records.quality_*).
const PARTICLES_STEP: int = 4 # Шаг квантования — чтобы узлы пула переиспользовались
const PARTICLES_POOL_WARMUP: int = 8 # Сколько узлов создать заранее, на загрузке

var shake_trauma: float = 0.0
var shake_decay: float = 3.0
var shake_strength: float = 14.0
var hitstop_active: bool = false
var flash_layer: CanvasLayer
var flash_rect: ColorRect
var flash_tween: Tween = null
var burst_root: Node2D = null
var burst_pool: Array[CPUParticles2D] = []
var live_particles: int = 0
var burst_node_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Слой вспышки поверх всего интерфейса, но без перехвата кликов.
	flash_layer = CanvasLayer.new()
	flash_layer.layer = 100
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash_rect)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Engine.time_scale = 1.0 # на случай, если hit-stop не успел завершиться
	burst_root = Node2D.new()
	burst_root.name = "Bursts"
	burst_root.z_index = 5 # Поверх мира, но под HUD (он в CanvasLayer)
	add_child(burst_root)
	for i in range(PARTICLES_POOL_WARMUP):
		burst_pool.append(_create_burst())

func _process(delta: float) -> void:
	# Тряска камеры: затухающая «травма», смещение пропорционально её квадрату.
	if shake_trauma <= 0.0:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		shake_trauma = 0.0
		return
	if get_tree().paused:
		cam.offset = Vector2.ZERO
		return
	shake_trauma = maxf(0.0, shake_trauma - delta * shake_decay)
	var power: float = shake_trauma * shake_trauma
	# Множитель из настроек («Тряска экрана»): слабая = 45% амплитуды, выключена = 0.
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * power * Records.shake_factor()
	if shake_trauma <= 0.0:
		cam.offset = Vector2.ZERO

func shake(amount: float = 0.5, decay: float = 3.0) -> void:
	# amount: 0.2 — лёгкий толчок, 1.0 — землетрясение.
	# Если тряска выключена в настройках — не копим «травму» вовсе,
	# иначе камера дёрнется сразу после включения обратно.
	if Records.shake_factor() <= 0.0:
		return
	shake_trauma = clampf(maxf(shake_trauma, amount), 0.0, 1.0)
	shake_decay = decay

## Мгновенно вернуть камеру на место (нужно при выключении тряски и на паузе).
func clear_shake() -> void:
	shake_trauma = 0.0
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		cam.offset = Vector2.ZERO

func flash(flash_color: Color = Color(1.0, 0.0, 0.0), alpha: float = 0.35, duration: float = 0.35) -> void:
	# Вспышки выключены в настройках — не рисуем совсем (мигание мешает не всем одинаково).
	if flash_rect == null or not Records.settings_flashes:
		return
	flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, alpha * Records.quality_flash_scale())
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "color:a", 0.0, duration)

func hitstop(duration: float = 0.06, slow: float = 0.05) -> void:
	# Короткое замедление мира: удар «чувствуется» весомее.
	if hitstop_active:
		return
	hitstop_active = true
	Engine.time_scale = slow
	# Ждём в реальном времени, иначе таймер сам себя замедлит.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	hitstop_active = false

func burst(pos: Vector2, burst_color: Color, amount: int = 12, speed: float = 140.0) -> void:
	if burst_root == null:
		return
	# 1. Потолок на один взрыв: боссу 40 хватает с запасом.
	amount = mini(amount, Records.quality_burst_particles())
	# 2. Общий бюджет: если экран уже забит, новые взрывы слабее или пропускаются.
	var budget: int = Records.quality_max_particles() - live_particles
	if budget < PARTICLES_STEP:
		return
	amount = mini(amount, budget)
	# 3. Квантование: узлы пула с одинаковым amount не пересобирают буфер.
	amount = int(amount / PARTICLES_STEP) * PARTICLES_STEP
	if amount < PARTICLES_STEP:
		return
	var node: CPUParticles2D = null
	while node == null and burst_pool.size() > 0:
		var candidate: CPUParticles2D = burst_pool.pop_back()
		if is_instance_valid(candidate):
			node = candidate
	if node == null:
		# Не плодим узлы бесконечно: малые частые взрывы иначе набьют пул.
		if burst_node_count >= Records.quality_burst_nodes():
			return
		node = _create_burst()
	node.fire(burst_color, amount, speed, pos)
	live_particles += amount

## Возврат узла в пул (вызывает сам взрыв, когда догорел).
func return_burst(node: CPUParticles2D, amount: int) -> void:
	live_particles = maxi(0, live_particles - amount)
	if is_instance_valid(node) and not burst_pool.has(node):
		burst_pool.append(node)

func _create_burst() -> CPUParticles2D:
	var node: CPUParticles2D = BurstScene.instantiate()
	burst_root.add_child(node)
	burst_node_count += 1
	return node

## Сколько частиц сейчас живо (для отладки и тестов).
func particle_load() -> int:
	return live_particles

## Сколько узлов-взрывов создано (для отладки и тестов).
func burst_node_load() -> int:
	return burst_node_count
