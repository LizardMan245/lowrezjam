extends Node

@export_range(0.1, 4.0, 0.05) var step_distance := 0.9
@export_range(0.0, 1.0, 0.05) var step_heat := 0.9
@export_range(0.0, 1.5, 0.05) var stride_width := 0.65

var _walker: Node3D
var _marks: Node
var _last := Vector3.ZERO
var _left_foot := false


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
	var stride := here - _last
	stride.y = 0.0
	if stride.length() < step_distance:
		return
	_last = here
	_left_foot = not _left_foot
	var side := Vector3(stride.z, 0.0, -stride.x).normalized() * stride_width * 0.5
	_marks.drop(here + (side if _left_foot else -side), step_heat)
