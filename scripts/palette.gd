class_name Palette
extends RefCounted
## Палитра для дальтоников (Records.settings_colorblind).
##
## Проблема: в обычной палитре «снаряды врага» и «яд игрока» — оба зелёные,
## кристаллы опыта — от голубого до зелёного, лечение — зелёное, а снаряды
## героя — оранжевые. Для красно-зелёных форм дальтонизма (дейтеранопия и
## протанопия — ~99% случаев) всё это сливается в одно пятно.
##
## Решение: три цветовые семьи, различимые и по оттенку, и по яркости —
##   опасность  → маджента (яркая, «неоново-розовая»)
##   награда    → бело-голубой (ярче всего на экране)
##   своя магия → синий (яд и трясина)
## Числа урона остаются жёлтыми, лечение уходит в голубой (плюс у него уже
## есть знак «+», так что цвет — не единственная подсказка).
##
## Палитра применяется в момент создания объекта: новые кристаллы и снаряды
## получают новые цвета сразу, старые — при следующем спавне (кристаллы также
## перекрашиваются при слиянии).

## Включена ли альтернативная палитра.
static func enabled() -> bool:
	return bool(Records.settings_colorblind)

static func _pick(normal: Color, safe: Color) -> Color:
	return safe if enabled() else normal

## Снаряд врага (плевун и всё, что летит в игрока).
static func enemy_shot() -> Color:
	return _pick(Color(0.45, 0.95, 0.4), Color(1.0, 0.25, 0.85))

## Кристалл опыта: цвет тира. В безопасной палитре тир дополнительно читается
## по размеру (масштаб 1.0 / 1.35 / 1.7 / 2.1), а цвет идёт от белого к синему.
static func gem(value: int) -> Color:
	if not enabled():
		if value >= 50:
			return Color(1.0, 0.8, 0.25) # золотой
		elif value >= 20:
			return Color(0.85, 0.45, 1.0) # фиолетовый
		elif value >= 5:
			return Color(0.45, 1.0, 0.55) # зелёный
		return Color(0.35, 0.9, 1.0) # голубой
	if value >= 50:
		return Color(0.2, 0.65, 1.0)
	elif value >= 20:
		return Color(0.45, 0.82, 1.0)
	elif value >= 5:
		return Color(0.72, 0.93, 1.0)
	return Color(0.95, 0.99, 1.0)

## Частицы при сборе кристалла.
static func gem_burst() -> Color:
	return _pick(Color(0.5, 0.9, 1.0), Color(0.8, 0.95, 1.0))

## Взрыв опасности: бомбардир и метеорит — то, что бьёт по игроку.
static func danger_impact() -> Color:
	return _pick(Color(1.0, 0.55, 0.2), Color(1.0, 0.3, 0.85))

## Лечение: цифры «+N» и вспышки у лекаря.
static func heal() -> Color:
	return _pick(Color(0.45, 1.0, 0.5), Color(0.3, 0.85, 1.0))

## Цифры урона.
static func damage_text() -> Color:
	return _pick(Color(1.0, 0.9, 0.35), Color(1.0, 0.95, 0.55))

## Телеграф ловушки арены — заливка. kind: "meteor" | "spikes".
static func hazard_fill(kind: String) -> Color:
	if not enabled():
		if kind == "meteor":
			return Color(1.0, 0.45, 0.1, 0.18)
		return Color(0.85, 0.85, 0.95, 0.16)
	if kind == "meteor":
		return Color(1.0, 0.25, 0.85, 0.2)
	return Color(0.6, 0.5, 0.95, 0.18)

## Телеграф ловушки арены — контур.
static func hazard_edge(kind: String) -> Color:
	if not enabled():
		if kind == "meteor":
			return Color(1.0, 0.6, 0.2, 0.85)
		return Color(0.8, 0.85, 1.0, 0.7)
	if kind == "meteor":
		return Color(1.0, 0.35, 0.9, 0.9)
	return Color(0.75, 0.6, 1.0, 0.8)

## Ядовитое облако — магия игрока (не путать с враждебной зеленью).
static func poison() -> Color:
	return _pick(Color(0.4, 0.9, 0.35), Color(0.25, 0.5, 1.0))

## Частицы ядовитого облака.
static func poison_burst() -> Color:
	return _pick(Color(0.45, 0.95, 0.4), Color(0.4, 0.65, 1.0))

## Зона трясины на карте «Топкие болота».
static func slow_zone() -> Color:
	return _pick(Color(0.16, 0.30, 0.20, 0.55), Color(0.12, 0.2, 0.42, 0.55))
