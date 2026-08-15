extends Camera3D

var _source: Camera3D


func _ready() -> void:
	process_priority = 100
	_source = get_tree().get_first_node_in_group("game_camera") as Camera3D
	if _source == null:
		push_warning("overlaycamera found no node in the \"game_camera\" group")
		set_process(false)


func _process(_delta: float) -> void:
	global_transform = _source.global_transform
	projection = _source.projection
	size = _source.size
	fov = _source.fov
	near = _source.near
	far = _source.far
