extends Area3D

@export var data_name: StringName = &"fragment"
@export_range(0, 21) var ram_cost := 3
@export_range(0.1, 5.0, 0.05) var download_seconds := 1.0
@export var spin_speed := 1.2
@export_range(0.0, 1.0, 0.05) var taken_opacity := 0.5

var held := false

var _progress := 0.0
var _visuals: Array[GeometryInstance3D] = []


func _ready() -> void:
	add_to_group("blueprint")
	_collect_visuals(self)


func _collect_visuals(node: Node) -> void:
	if node is GeometryInstance3D:
		_visuals.append(node)
	for child in node.get_children():
		_collect_visuals(child)


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


func _physics_process(delta: float) -> void:
	if held:
		return
	if not has_overlapping_areas() or not Input.is_action_pressed("interact"):
		_cancel()
		return

	_progress += delta / download_seconds
	_tell_ui("show_download", clampf(_progress, 0.0, 1.0))
	if _progress < 1.0:
		return

	held = true
	_progress = 0.0
	_tell_ui("show_download", -1.0)
	_tell_ui("show_success", 0.0)
	_fade(taken_opacity)
	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory != null:
		inventory.collect(self)


func restore() -> void:
	held = false
	_progress = 0.0
	_fade(1.0)


func _cancel() -> void:
	if _progress <= 0.0:
		return
	_progress = 0.0
	_tell_ui("show_download", -1.0)


func _tell_ui(what: StringName, value: float) -> void:
	var ui := get_tree().get_first_node_in_group("ui")
	if ui == null or not ui.has_method(what):
		return
	if what == &"show_success":
		ui.show_success()
	else:
		ui.show_download(value)


func _fade(alpha: float) -> void:
	for visual in _visuals:
		visual.transparency = clampf(1.0 - alpha, 0.0, 1.0)
