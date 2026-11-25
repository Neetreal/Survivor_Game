class_name TrailLine
extends Line2D
## След за снарядом: ломаная из точек в глобальных координатах.
##
## Почему Line2D, а не частицы: снарядов на экране может быть много, а линия —
## это одна отрисовка с фиксированным числом точек, без новых узлов и без
## общего бюджета частиц. Точки живут фиксированное время и сами отваливаются.
##
## Узел рисуется в глобальных координатах (top_level), поэтому родитель
## может крутиться и масштабироваться как угодно — след не поедет.

const MAX_POINTS: int = 12

var lifetime: float = 0.22 # Сколько живёт точка, сек
var follow: Node2D = null # За кем тянемся (обычно родитель)
var _points: Array = [] # [{pos: Vector2, age: float}]

func setup(target: Node2D, color: Color, width: float = 6.0, life: float = 0.22) -> void:
	follow = target
	lifetime = life
	top_level = true
	z_index = -1
	# self.width обязателен: параметр функции затеняет свойство, и без self
	# след рисовался бы дефолтной толщиной 10 px.
	self.width = width
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	# Аддитивное смешивание: след светится, а не выглядит серой полосой поверх фона.
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	var gradient := Gradient.new()
	# Свежий конец яркий, хвост растворяется.
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.85 * color.a))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.5, Color(color.r, color.g, color.b, 0.35 * color.a))
	self.gradient = gradient

func _process(delta: float) -> void:
	if follow == null or not is_instance_valid(follow):
		queue_free()
		return
	var pos: Vector2 = follow.global_position
	if _points.is_empty() or _points[0]["pos"].distance_to(pos) > 1.5:
		_points.push_front({"pos": pos, "age": 0.0})
	for point in _points:
		point["age"] += delta
	while not _points.is_empty() and (float(_points[-1]["age"]) > lifetime or _points.size() > MAX_POINTS):
		_points.pop_back()
	var flat: PackedVector2Array = PackedVector2Array()
	for point in _points:
		flat.append(point["pos"])
	points = flat
