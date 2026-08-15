extends SubViewportContainer

const RAY_COUNT := 128
const ORIGIN_COUNT := 7
const MAX_APERTURE_WIDTH := 1.4

@export_group("Player vision")
@export var mask_color := Color(0.0, 0.0, 0.0, 1.0)
@export_flags_3d_physics var occluder_mask := 1
@export_flags_3d_physics var window_mask := 0
@export_range(0.0, 1.0, 0.01) var window_shadow := 0.2
@export_range(0.0, 20.0) var edge_softness_degrees := 3.0
@export_range(0.0, 10.0) var distance_fade := 1.5
@export_range(0.0, 2.0, 0.01) var wall_bleed := 0.35
@export_range(0.0, 1.0, 0.01) var shadow_softness := 0.05
@export_range(0.0, MAX_APERTURE_WIDTH, 0.01) var aperture_width := 0.6
@export_range(0.0, 45.0, 0.5) var fan_margin_degrees := 15.0

@export_group("Thermal camera")
@export var thermal_screen: NodePath
@export_range(0.0, 40.0) var thermal_distance := 12.0
@export_range(0.0, 20.0) var thermal_edge_softness_degrees := 8.0
@export_range(0.0, 10.0) var thermal_distance_fade := 3.0

var thermal_angle_degrees := 0.0

var _viewport: SubViewport
var _player: Node3D
var _material: ShaderMaterial
var _thermal: ShaderMaterial
var _ranges := PackedFloat32Array()
var _texture: ImageTexture
var _query := PhysicsRayQueryParameters3D.new()
var _eye := Vector3.ZERO
var _eye_dir := Vector2(0.0, 1.0)
var _eye_right := Vector2(1.0, 0.0)


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

	_ranges.resize(RAY_COUNT * ORIGIN_COUNT * 2)
	_ranges.fill(0.0)
	_texture = ImageTexture.create_from_image(_bake_image())
	_material.set_shader_parameter("vision_ranges", _texture)

	var screen := get_node_or_null(thermal_screen) as CanvasItem
	if screen != null:
		_thermal = screen.material as ShaderMaterial
	if _thermal != null:
		_thermal.set_shader_parameter("vision_ranges", _texture)
		_thermal.set_shader_parameter("world_tex", _viewport.get_texture())

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


func _origin_offset(index: int) -> float:
	if ORIGIN_COUNT < 2:
		return 0.0
	return float(index) / float(ORIGIN_COUNT - 1) - 0.5


func _cast_fan() -> void:
	_eye = _player.get_eye_position()
	_eye_dir = _player.facing
	_eye_right = Vector2(_eye_dir.y, -_eye_dir.x)

	var space := _player.get_world_3d().direct_space_state
	var reach: float = maxf(_player.view_distance, thermal_reach())
	var fan_half := _fan_half_angle()
	var centre := atan2(_eye_dir.x, _eye_dir.y)
	var right := Vector3(_eye_right.x, 0.0, _eye_right.y)

	for k in ORIGIN_COUNT:
		var origin := _eye + right * (_origin_offset(k) * aperture_width)
		var row := k * RAY_COUNT
		for i in RAY_COUNT:
			var angle := centre - fan_half + (float(i) + 0.5) / float(RAY_COUNT) * 2.0 * fan_half
			_query.from = origin
			_query.to = origin + Vector3(sin(angle), 0.0, cos(angle)) * reach

			var slot := (row + i) * 2
			_ranges[slot] = reach
			_ranges[slot + 1] = reach

			_query.collision_mask = occluder_mask | window_mask
			var hit := space.intersect_ray(_query)
			if hit.is_empty():
				continue

			var dist: float = origin.distance_to(hit.position) + wall_bleed
			if _is_solid(hit.collider):
				_ranges[slot] = dist
				continue

			_ranges[slot + 1] = dist
			_query.collision_mask = occluder_mask
			var behind := space.intersect_ray(_query)
			if not behind.is_empty():
				_ranges[slot] = origin.distance_to(behind.position) + wall_bleed


func _is_solid(collider: Object) -> bool:
	if collider is CollisionObject3D:
		return (collider as CollisionObject3D).collision_layer & occluder_mask != 0
	return true


func _fan_half_angle() -> float:
	var widest: float = maxf(_player.vision_angle_degrees, thermal_angle_degrees)
	return deg_to_rad(widest) * 0.5 + deg_to_rad(fan_margin_degrees)


func thermal_reach() -> float:
	return thermal_distance if thermal_angle_degrees > 0.0 else 0.0


func _bake_image() -> Image:
	return Image.create_from_data(
		RAY_COUNT, ORIGIN_COUNT, false, Image.FORMAT_RGF, _ranges.to_byte_array())


func _push_camera(camera: Camera3D) -> void:
	var basis := camera.global_transform.basis
	var half_height := camera.size * 0.5
	var frame := _viewport.size
	var aspect := float(frame.x) / float(frame.y) if frame.y > 0 else 1.0

	for mat in _screens():
		mat.set_shader_parameter("cam_pos", camera.global_position)
		mat.set_shader_parameter("cam_right", basis.x)
		mat.set_shader_parameter("cam_up", basis.y)
		mat.set_shader_parameter("cam_forward", -basis.z)
		mat.set_shader_parameter("cam_half_extents", Vector2(half_height * aspect, half_height))
		mat.set_shader_parameter("ground_height", 0.0)


func _push_cone() -> void:
	for mat in _screens():
		mat.set_shader_parameter("eye_pos", Vector2(_eye.x, _eye.z))
		mat.set_shader_parameter("eye_dir", _eye_dir)
		mat.set_shader_parameter("eye_right", _eye_right)
		mat.set_shader_parameter("aperture_width", aperture_width)
		mat.set_shader_parameter("fan_half_angle", _fan_half_angle())
		mat.set_shader_parameter("shadow_softness", shadow_softness)
		mat.set_shader_parameter("window_shadow", window_shadow)

	_material.set_shader_parameter("half_angle", deg_to_rad(_player.vision_angle_degrees) * 0.5)
	_material.set_shader_parameter("view_distance", _player.view_distance)
	_material.set_shader_parameter("edge_softness", deg_to_rad(edge_softness_degrees))
	_material.set_shader_parameter("distance_fade", distance_fade)
	_material.set_shader_parameter("mask_color", mask_color)

	if _thermal == null:
		return
	_thermal.set_shader_parameter("half_angle", deg_to_rad(thermal_angle_degrees) * 0.5)
	_thermal.set_shader_parameter("view_distance", thermal_reach())
	_thermal.set_shader_parameter("edge_softness", deg_to_rad(thermal_edge_softness_degrees))
	_thermal.set_shader_parameter("distance_fade", thermal_distance_fade)


func _screens() -> Array:
	return [_material] if _thermal == null else [_material, _thermal]
