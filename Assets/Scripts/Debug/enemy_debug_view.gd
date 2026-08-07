extends MeshInstance3D

const EnemyActor = preload("res://Assets/Scripts/Enemies/enemy_actor.gd")

const CONE_SEGMENTS := 24
const CONE_LIFT := 0.06
const CONE_FILL_ALPHA := 0.28
const CONE_EDGE_ALPHA := 0.85
const PATH_ALPHA := 0.55
const LAST_SEEN_COLOR := Color(1.0, 1.0, 1.0)
const METER_BACKING := Color(0.05, 0.05, 0.08, 0.75)

@export var enabled := true
@export var toggle_key: Key = KEY_F3
@export var show_sight_cone := true
@export var show_state_indicator := true
@export var show_navigation_target := true
@export var show_detection_meter := true
@export var last_known_states: Array[StringName] = [&"Alert", &"Chase", &"Search"]
@export var indicator_offset := Vector3(0.0, 0.0, -1.1)
@export_range(0.1, 2.0, 0.05) var indicator_size := 0.5
@export_range(0.2, 4.0, 0.05) var meter_width := 1.2
@export_range(0.05, 1.0, 0.05) var meter_height := 0.18
@export var fallback_color := Color(0.8, 0.4, 1.0)
@export var state_colors := {
	&"RoamWalk": Color(0.25, 1.0, 0.4),
	&"RoamIdle": Color(0.3, 0.6, 1.0),
	&"Alert": Color(1.0, 1.0, 1.0),
	&"Chase": Color(1.0, 0.15, 0.1),
	&"Search": Color(1.0, 0.75, 0.1),
}

var _enemy: EnemyActor
var _agent: NavigationAgent3D
var _canvas := ImmediateMesh.new()
var _query := PhysicsRayQueryParameters3D.new()
var _toggle_held := false


func _ready() -> void:
	_enemy = get_parent() as EnemyActor
	if _enemy == null:
		push_warning("EnemyDebugView expects to be a child of an enemy actor.")
		set_physics_process(false)
		return

	_agent = _enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	mesh = _canvas
	material_override = _build_overlay_material()
	_query.collision_mask = _enemy.sight_mask
	_query.exclude = _bodies_to_ignore()
	visible = enabled


func _build_overlay_material() -> StandardMaterial3D:
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.vertex_color_use_as_albedo = true
	overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
	overlay.no_depth_test = true
	overlay.disable_receive_shadows = true
	return overlay


func _bodies_to_ignore() -> Array[RID]:
	var ignored: Array[RID] = [_enemy.get_rid()]
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null:
		ignored.append(player.get_rid())
	return ignored


func _physics_process(_delta: float) -> void:
	_poll_toggle()
	if not enabled:
		return

	_canvas.clear_surfaces()
	var tint := _state_tint()
	if show_sight_cone:
		_draw_sight_cone(tint)
	if show_navigation_target:
		_draw_navigation_target(tint)
	if show_state_indicator:
		_draw_state_indicator(tint)
	if show_detection_meter:
		_draw_detection_meter(tint)


func _poll_toggle() -> void:
	var held := Input.is_key_pressed(toggle_key)
	if held and not _toggle_held:
		enabled = not enabled
		visible = enabled
		if not enabled:
			_canvas.clear_surfaces()
	_toggle_held = held


func _state_tint() -> Color:
	return state_colors.get(_enemy.get_state_name(), fallback_color)


func _ground_level() -> float:
	return _enemy.global_position.y + CONE_LIFT


func _draw_sight_cone(tint: Color) -> void:
	var eye := _enemy.get_eye_position()
	var apex := Vector3(eye.x, _ground_level(), eye.z)
	var half := deg_to_rad(_enemy.vision_angle_degrees) * 0.5
	var centre := atan2(_enemy.facing.x, _enemy.facing.y)

	var rim: Array[Vector3] = []
	for i in CONE_SEGMENTS + 1:
		var angle := centre - half + 2.0 * half * float(i) / float(CONE_SEGMENTS)
		rim.append(_unblocked_point(eye, angle))

	var fill := Color(tint.r, tint.g, tint.b, CONE_FILL_ALPHA)
	_canvas.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in CONE_SEGMENTS:
		_add_vertex(apex, fill)
		_add_vertex(rim[i], fill)
		_add_vertex(rim[i + 1], fill)
	_canvas.surface_end()

	var edge := Color(tint.r, tint.g, tint.b, CONE_EDGE_ALPHA)
	_canvas.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_line(apex, rim[0], edge)
	_add_line(apex, rim[CONE_SEGMENTS], edge)
	for i in CONE_SEGMENTS:
		_add_line(rim[i], rim[i + 1], edge)
	_canvas.surface_end()


func _unblocked_point(eye: Vector3, angle: float) -> Vector3:
	var direction := Vector3(sin(angle), 0.0, cos(angle))
	var reach: float = _enemy.view_distance
	_query.from = eye
	_query.to = eye + direction * reach
	var hit := _enemy.get_world_3d().direct_space_state.intersect_ray(_query)
	if not hit.is_empty():
		reach = eye.distance_to(hit.position)
	return Vector3(eye.x, _ground_level(), eye.z) + direction * reach


func _draw_navigation_target(tint: Color) -> void:
	if _agent == null:
		return
	var path := Color(tint.r, tint.g, tint.b, PATH_ALPHA)

	_canvas.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_line(_flatten(_enemy.global_position), _flatten(_agent.target_position), path)
	if last_known_states.has(_enemy.get_state_name()):
		_add_cross(_flatten(_enemy.last_known_player_spot), 0.3, LAST_SEEN_COLOR)
	_canvas.surface_end()


func _draw_state_indicator(tint: Color) -> void:
	_canvas.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(_indicator_centre(), indicator_size, indicator_size, tint)
	_canvas.surface_end()


func _draw_detection_meter(tint: Color) -> void:
	var progress := _enemy.get_detection_progress()
	if progress <= 0.0 or progress >= 1.0:
		return

	var centre := _indicator_centre() + Vector3(0.0, 0.0, -indicator_size * 0.9)
	_canvas.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(centre, meter_width, meter_height, METER_BACKING)
	var filled := meter_width * progress
	var left := centre.x - meter_width * 0.5
	_add_quad(Vector3(left + filled * 0.5, centre.y, centre.z), filled, meter_height, tint)
	_canvas.surface_end()


func _indicator_centre() -> Vector3:
	var centre := _enemy.global_position + indicator_offset
	return Vector3(centre.x, _ground_level(), centre.z)


func _flatten(spot: Vector3) -> Vector3:
	return Vector3(spot.x, _ground_level(), spot.z)


func _add_quad(centre: Vector3, width: float, height: float, color: Color) -> void:
	var x := width * 0.5
	var z := height * 0.5
	var a := centre + Vector3(-x, 0.0, -z)
	var b := centre + Vector3(x, 0.0, -z)
	var c := centre + Vector3(x, 0.0, z)
	var d := centre + Vector3(-x, 0.0, z)
	_add_vertex(a, color)
	_add_vertex(b, color)
	_add_vertex(c, color)
	_add_vertex(a, color)
	_add_vertex(c, color)
	_add_vertex(d, color)


func _add_vertex(world_spot: Vector3, color: Color) -> void:
	_canvas.surface_set_color(color)
	_canvas.surface_add_vertex(to_local(world_spot))


func _add_line(from: Vector3, to: Vector3, color: Color) -> void:
	_add_vertex(from, color)
	_add_vertex(to, color)


func _add_cross(centre: Vector3, reach: float, color: Color) -> void:
	_add_line(centre + Vector3(-reach, 0.0, -reach), centre + Vector3(reach, 0.0, reach), color)
	_add_line(centre + Vector3(-reach, 0.0, reach), centre + Vector3(reach, 0.0, -reach), color)
