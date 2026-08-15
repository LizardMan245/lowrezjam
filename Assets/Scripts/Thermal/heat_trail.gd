extends Node

@export_range(0.1, 4.0, 0.05) var step_distance := 0.9
@export_range(0.0, 1.0, 0.05) var step_heat := 0.9

var _walker: Node3D
var _marks: Node
var _last := Vector3.ZERO


func _ready() -> void:
	_walker = get_parent() as Node3D
	if _walker == null:
		push_warning("heattrail needs a node3d parent")
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if _marks == null:
		_marks = get_tree().get_first_node_in_group("heat_marks")
		if _marks == null:
			return
		_last = _walker.global_position
		return

	var here := _walker.global_position
	if here.distance_to(_last) < step_distance:
		return
	_last = here
	_marks.drop(here, step_heat)
