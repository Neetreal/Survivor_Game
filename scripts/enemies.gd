class_name Enemies
extends RefCounted
## Единый реестр живых врагов.
##
## Раньше 18 мест в 7 файлах делали get_tree().get_nodes_in_group("enemies") —
## каждый вызов обходит дерево сцены и собирает массив заново. Хуже всего это было
## в расчёте расталкивания врагов (enemy.gd) и в уроне по площади: цикл «для каждого
## врага — снова весь список врагов» превращался в O(n²) с аллокациями на каждом шаге.
##
## Теперь враг сам регистрируется при входе в дерево и снимается с учёта при выходе,
## а запрос — это просто возврат готового массива. Порядок и содержимое совпадают с
## группой "enemies": узлы, поставленные в очередь на удаление, остаются в списке до
## фактического удаления (как и в группе), поэтому вызывающий код, проверяющий
## is_queued_for_deletion(), работает как раньше.

static var _list: Array = []


static func register(enemy: Node) -> void:
	if not _list.has(enemy):
		_list.append(enemy)


static func unregister(enemy: Node) -> void:
	_list.erase(enemy)


## Список живых врагов. Возвращается внутренний массив — только для чтения,
## не сортировать и не изменять (для этого сделай duplicate()).
static func all() -> Array:
	return _list


static func count() -> int:
	return _list.size()


## Сколько врагов реально может принять игра (лимит минус живые).
static func free_slots(cap: int) -> int:
	return maxi(0, cap - _list.size())


## Полная сверка с деревом — на случай врагов, созданных в обход Enemy._ready()
## (например, при загрузке новой карты). Стоит копейки: один вызов за забег.
static func resync() -> void:
	_list = _list.filter(func(e): return is_instance_valid(e))


static func clear() -> void:
	_list.clear()
