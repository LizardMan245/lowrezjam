extends SubViewportContainer

## Builds the robot's field of view and hands it to the composite shader on this
## container.
##
## Every physics frame a fan of rays is cast across the mounted camera's cone and
## the hit distances are baked into a 1D texture -- a visibility polygon. The
## shader turns that into the mask, so walls throw shadows and corners hide what
## sits behind them.
##
## Swapping this container's material for another shader that includes
## vision_field.gdshaderinc gives a different vision mode (thermal, ...) driven by
## the exact same field.

## One ray per texel of the field. 128 across 45 degrees is well under a pixel
## wide at 64x64, so shadow edges land where the geometry does.
const RAY_COUNT := 128

## Extra distance past whatever a ray hits, so the surface the robot is looking
## at stays visible instead of the shadow starting on its front face.
@export_range(0.0, 2.0, 0.01) var wall_bleed := 0.35
## Feathering on the two edges of the cone, in degrees.
@export_range(0.0, 20.0) var edge_softness_degrees := 3.0
## How much of the far end of the cone fades out instead of cutting off, in units.
@export_range(0.0, 10.0) var distance_fade := 1.5
## How far a shadow edge fades, in world units. The fade starts at the occluder
## and runs into it, so the surface being looked at stays lit and goes dark as it
## carries on into the object. Keep it near the thickness of your walls: past
## that the gradient runs out the back and onto the floor behind.
@export_range(0.0, 4.0, 0.01) var shadow_softness := 0.25
## Extra sideways penumbra per world unit behind a corner. Only silhouettes have
## anything to spread, so this widens shadows cast around corners the further
## they reach without touching the shadow directly behind a wall. Feathers
## backwards only -- the sharp traced edge is as far forward as a shadow reaches,
## whatever the softness.
@export_range(0.0, 2.0, 0.01) var shadow_spread := 0.35
## Which physics layers block the robot's view.
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
	# After camera_rig.gd has moved the camera for this frame, so the mask is
	# built against where the camera actually ends up.
	process_priority = 50
	_viewport = get_child(0) as SubViewport
	_material = material as ShaderMaterial
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _viewport == null or _material == null or _player == null:
		push_warning("VisionField needs a SubViewport child, a ShaderMaterial and a node in the \"player\" group.")
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


## Casts the fan and records how far the view reaches at each angle.
func _cast_fan() -> void:
	_eye = _player.get_eye_position()
	_eye_dir = _player.facing

	var space := _player.get_world_3d().direct_space_state
	var reach: float = _player.view_distance
	var half := deg_to_rad(_player.vision_angle_degrees) * 0.5
	var centre := atan2(_eye_dir.x, _eye_dir.y)

	for i in RAY_COUNT:
		# Aim at texel centres so the shader's lookup lines up with the fan.
		var angle := centre - half + (float(i) + 0.5) / float(RAY_COUNT) * 2.0 * half
		_query.from = _eye
		_query.to = _eye + Vector3(sin(angle), 0.0, cos(angle)) * reach
		var hit := space.intersect_ray(_query)
		_ranges[i] = reach if hit.is_empty() else _eye.distance_to(hit.position) + wall_bleed


func _bake_image() -> Image:
	return Image.create_from_data(RAY_COUNT, 1, false, Image.FORMAT_RF, _ranges.to_byte_array())


## The shader maps screen pixels back onto the ground plane itself, which needs
## the game camera. Orthographic only -- a perspective camera would need the ray
## direction to vary per pixel.
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
	# Paired with the fan, not with the player's current position, so the mask
	# and the shadows in it always describe the same instant.
	_material.set_shader_parameter("eye_pos", Vector2(_eye.x, _eye.z))
	_material.set_shader_parameter("eye_dir", _eye_dir)
	_material.set_shader_parameter("half_angle", deg_to_rad(_player.vision_angle_degrees) * 0.5)
	_material.set_shader_parameter("edge_softness", deg_to_rad(edge_softness_degrees))
	_material.set_shader_parameter("view_distance", _player.view_distance)
	_material.set_shader_parameter("distance_fade", distance_fade)
	_material.set_shader_parameter("shadow_softness", shadow_softness)
	_material.set_shader_parameter("shadow_spread", shadow_spread)
