extends CPUParticles2D
## Одноразовый взрыв частиц.
## Узлы НЕ создаются и не удаляются на каждый взрыв — FX держит их в пуле и
## переиспользует. Иначе смерть крупного врага (60 частиц) в толпе вызывала
## всплеск аллокаций и подвисание кадра.

var life: float = 0.6
var age: float = 0.0
var active: bool = false
var spawned_amount: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	emitting = false
	visible = false

## Запуск из пула: настраиваем и включаем.
func fire(burst_color: Color, amount_count: int, speed: float, spawn_position: Vector2) -> void:
	color = burst_color
	# amount меняем только если он реально другой — иначе движок пересобирает буфер.
	if amount != amount_count:
		amount = amount_count
	spawned_amount = amount_count
	initial_velocity_min = speed * 0.4
	initial_velocity_max = speed
	global_position = spawn_position
	rotation = randf() * TAU
	active = true
	age = 0.0
	visible = true
	emitting = true

func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	if age > life:
		release()

## Погасить и вернуть в пул (с освобождением бюджета частиц).
func release() -> void:
	if not active:
		return
	active = false
	emitting = false
	visible = false
	age = 0.0
	FX.return_burst(self, spawned_amount)
	spawned_amount = 0
