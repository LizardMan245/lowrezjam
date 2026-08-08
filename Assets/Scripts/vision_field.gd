extends SubViewportContainer

const RAY_COUNT := 128

@export_range(0.0, 2.0, 0.01) var wall_bleed := 0.35
@export_range(0.0, 20.0) var edge_softness_degrees := 3.0
@export_range(0.0, 10.0) var distance_fade := 1.5
@export_range(0.0, 4.0, 0.01) var shadow_softness := 0.25
@export_range(0.0, 2.0, 0.01) var shadow_spread := 0.35
@export_flags_3d_physics var occluder_mask := 1

var _viewport: SubViewport
var _player: Node3D
var _material: ShaderMaterial
var _ranges := PackedFloat32Array()
var _texture: ImageTexture
var _query := PhysicsRayQueryParameters3D.new()
var _eye := Vector3.ZERO
var _eye_dir := Vector2(0.0, 1.0)


func _ready() -> void:
	process_priority = 50
	_viewport = get_child(0) as SubViewport
	_material = material as ShaderMaterial
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _viewport == null or _material == null or _player == null:
		push_warning("visionfield needs subviewport, shadermatertial a node in the \"player\" group")
		set_process(false)
		set_physics_process(false)
		return

	_ranges.resize(RAY_COUNT)
	_ranges.fill(0.0)
	_texture = ImageTexture.create_from_image(_bake_image())
	_material.set_shader_parameter("vision_ranges", _texture)

	_query.collision_mask = occluder_mask
	_query.exclude = [_player.get_rid()]
	_cast_fan()


func _physics_process(_delta: float) -> void:
	_cast_fan()
	_texture.update(_bake_image())


func _process(_delta: float) -> void:
	var camera := _viewport.get_camera_3d()
	if camera == null:
		return
	_push_camera(camera)
	_push_cone()


func _cast_fan() -> void:
	_eye = _player.get_eye_position()
	_eye_dir = _player.facing

	var space := _player.get_world_3d().direct_space_state
	var reach: float = _player.view_distance
	var half := deg_to_rad(_player.vision_angle_degrees) * 0.5
	var centre := atan2(_eye_dir.x, _eye_dir.y)

	for i in RAY_COUNT:
		var angle := centre - half + (float(i) + 0.5) / float(RAY_COUNT) * 2.0 * half
		_query.from = _eye
		_query.to = _eye + Vector3(sin(angle), 0.0, cos(angle)) * reach
		var hit := space.intersect_ray(_query)
		_ranges[i] = reach if hit.is_empty() else _eye.distance_to(hit.position) + wall_bleed


func _bake_image() -> Image:
	return Image.create_from_data(RAY_COUNT, 1, false, Image.FORMAT_RF, _ranges.to_byte_array())


func _push_camera(camera: Camera3D) -> void:
	var basis := camera.global_transform.basis
	var half_height := camera.size * 0.5
	var frame := _viewport.size
	var aspect := float(frame.x) / float(frame.y) if frame.y > 0 else 1.0

	_material.set_shader_parameter("cam_pos", camera.global_position)
	_material.set_shader_parameter("cam_right", basis.x)
	_material.set_shader_parameter("cam_up", basis.y)
	_material.set_shader_parameter("cam_forward", -basis.z)
	_material.set_shader_parameter("cam_half_extents", Vector2(half_height * aspect, half_height))
	_material.set_shader_parameter("ground_height", 0.0)


func _push_cone() -> void:
	_material.set_shader_parameter("eye_pos", Vector2(_eye.x, _eye.z))
	_material.set_shader_parameter("eye_dir", _eye_dir)
	_material.set_shader_parameter("half_angle", deg_to_rad(_player.vision_angle_degrees) * 0.5)
	_material.set_shader_parameter("edge_softness", deg_to_rad(edge_softness_degrees))
	_material.set_shader_parameter("view_distance", _player.view_distance)
	_material.set_shader_parameter("distance_fade", distance_fade)
	_material.set_shader_parameter("shadow_softness", shadow_softness)
	_material.set_shader_parameter("shadow_spread", shadow_spread)
