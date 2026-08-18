extends Node

@export var needed := 3
@export var icon_off: Texture2D
@export var icon_on: Texture2D
@export var icon: NodePath

var held: Array[Node] = []
var selected := 0


func _ready() -> void:
	add_to_group("inventory")
	_refresh()


func collect(fragment: Node) -> void:
	if fragment in held:
		return
	held.append(fragment)
	selected = held.size() - 1
	_spend(fragment.ram_cost)
	_refresh()


func drop_selected() -> Node:
	if held.is_empty():
		return null
	selected = clampi(selected, 0, held.size() - 1)
	var fragment: Node = held[selected]
	held.remove_at(selected)
	selected = clampi(selected, 0, maxi(held.size() - 1, 0))
	_spend(-fragment.ram_cost)
	fragment.restore()
	_refresh()
	return fragment


func select_next(step: int) -> void:
	if held.is_empty():
		return
	selected = wrapi(selected + step, 0, held.size())
	_refresh()


func count() -> int:
	return held.size()


func has_all() -> bool:
	return held.size() >= needed


func _spend(amount: int) -> void:
	var ui := get_parent()
	if ui != null and ui.has_method("add_ram"):
		ui.add_ram(amount)


func _refresh() -> void:
	var rect := get_node_or_null(icon) as TextureRect
	if rect != null:
		rect.texture = icon_on if held.size() > 0 else icon_off
	var ui := get_parent()
	if ui != null and ui.has_method("show_held_data"):
		ui.show_held_data(held.size(), selected)
