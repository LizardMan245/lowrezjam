extends Camera3D

## Mirrors the game camera into the overlay viewport, which renders only the
## layers that must never be masked (the robot itself) and is drawn on top of the
## masked world. Both viewports share the same World3D, so this only has to match
## the camera to line the two images up exactly.

var _source: Camera3D


func _ready() -> void:
	# After camera_rig.gd has moved the real camera for this frame.
	process_priority = 100
	_source = get_tree().get_first_node_in_group("game_camera") as Camera3D
	if _source == null:
		push_warning("OverlayCamera found no node in the \"game_camera\" group.")
		set_process(false)


func _process(_delta: float) -> void:
	global_transform = _source.global_transform
	projection = _source.projection
	size = _source.size
	fov = _source.fov
	near = _source.near
	far = _source.far
