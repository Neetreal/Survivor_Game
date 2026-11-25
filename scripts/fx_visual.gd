class_name FxVisual
extends RefCounted
## Общие помощники для снарядов, заклинаний и предметов:
## спрайт вместо цветной фигуры, мягкое свечение и след.

## Поставить спрайт по id (например "fx_bolt"). Нет файла — остаётся фигура.
static func use_sprite(body: Sprite2D, fallback: CanvasItem, sprite_id: String) -> bool:
	if body == null:
		return false
	var path: String = "res://art/sprites/%s.png" % sprite_id
	if not ResourceLoader.exists(path):
		return false
	body.texture = load(path)
	body.visible = true
	if fallback != null:
		fallback.visible = false
	return true

## Тинт: цветная фигура красится в color, спрайт — в modulate (перемножается).
static func set_color(body: Sprite2D, fallback: Polygon2D, color: Color) -> void:
	if fallback != null:
		fallback.color = color
	if body != null:
		body.modulate = color

## Мягкое аддитивное свечение позади снаряда: одно растянутое пятно-спрайт.
static func add_glow(parent: Node2D, color: Color, size: float, alpha: float = 0.55) -> Sprite2D:
	var path: String = "res://art/sprites/fx_glow.png"
	if not ResourceLoader.exists(path):
		return null
	var glow := Sprite2D.new()
	glow.texture = load(path)
	glow.modulate = Color(color.r, color.g, color.b, alpha)
	glow.scale = Vector2.ONE * (size / 128.0)
	glow.z_index = -2
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	parent.add_child(glow)
	return glow

## След за родителем. Возвращает линию, если её удалось создать.
static func add_trail(parent: Node2D, color: Color, width: float = 6.0, life: float = 0.22) -> TrailLine:
	var trail := TrailLine.new()
	parent.add_child(trail)
	trail.setup(parent, color, width, life)
	return trail
