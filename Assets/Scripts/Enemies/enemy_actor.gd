extends CharacterBody3D

const NAVIGATION_SYNC_FRAMES := 120
const NAVIGATION_SNAP_LIMIT := 4.0

signal state_changed(previous: StringName, current: StringName)
signal player_detected
signal player_lost
signal animation_requested(animation: StringName)
signal sound_requested(stream: AudioStream)

@export_group("Senses")
@export_range(5.0, 180.0) var vision_angle_degrees := 70.0
@export_range(1.0, 40.0) var view_distance := 12.0
@export_range(0.0, 4.0) var eye_height := 0.6
@export_flags_3d_physics var sight_mask := 1
@export_range(0.0, 10.0, 0.05) var detection_time := 0.5
@export_range(0.0, 10.0, 0.05) var detection_decay_rate := 1.5

@export_group("Movement")
@export_range(1.0, 30.0) var turn_speed := 6.0
@export_range(1.0, 60.0) var brake_rate := 14.0
@export_range(0.1, 3.0, 0.05) var arrive_distance := 0.6

var facing := Vector2(0.0, 1.0)
var player_visible := false
var last_known_player_spot := Vector3.ZERO
var sight_seconds := 0.0

var _player: Node3D
var _agent: NavigationAgent3D
var _machine
var _visual: Node3D
var _animator: AnimationPlayer
var _speaker: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _sight_query := PhysicsRayQueryParameters3D.new()
var _detected_last_frame := false


func _ready() -> void:
	set_physics_process(false)
	_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_machine = get_node_or_null("StateMachine")
	_visual = get_node_or_null("Visual") as Node3D
	_animator = get_node_or_null("AnimationPlayer") as AnimationPlayer
	_speaker = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	_player = get_tree().get_first_node_in_group("player") as Node3D

	if _agent == null or _machine == null or _visual == null:
		push_warning("Enemy actor needs NavigationAgent3D, StateMachine and Visual child nodes.")
		return
	if _player == null:
		push_warning("Enemy actor found no node in the \"player\" group; it will only free roam.")

	_rng.randomize()
	_sight_query.collision_mask = sight_mask
	_sight_query.exclude = [get_rid()]
	_apply_facing()

	_machine.setup(self)
	_machine.state_changed.connect(_on_state_changed)
	await _navigation_map_ready()
	_machine.start()
	set_physics_process(true)


func _on_state_changed(previous: StringName, current: StringName) -> void:
	state_changed.emit(previous, current)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_update_senses(delta)
	_machine.physics_tick(delta)
	move_and_slide()


func _navigation_map_ready() -> void:
	for _frame in NAVIGATION_SYNC_FRAMES:
		if _has_synchronised_navigation_map():
			return
		await get_tree().physics_frame
	push_warning("Enemy actor gave up waiting for its navigation map to synchronise.")


func _has_synchronised_navigation_map() -> bool:
	var map := _agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	return flat_distance(NavigationServer3D.map_get_closest_point(map, global_position), global_position) < NAVIGATION_SNAP_LIMIT


func _update_senses(delta: float) -> void:
	var was_visible := player_visible
	player_visible = can_see_player()

	if player_visible:
		last_known_player_spot = _player.global_position
		sight_seconds = minf(sight_seconds + delta, detection_time)
	else:
		if was_visible:
			player_lost.emit()
		sight_seconds = maxf(sight_seconds - delta * detection_decay_rate, 0.0)

	var detected := has_detected_player()
	if detected and not _detected_last_frame:
		player_detected.emit()
	_detected_last_frame = detected


func can_see_player() -> bool:
	if _player == null:
		return false

	var eye := get_eye_position()
	var target := Vector3(_player.global_position.x, eye.y, _player.global_position.z)
	var flat := Vector2(target.x - eye.x, target.z - eye.z)
	var range_to_player := flat.length()
	if range_to_player < 0.001 or range_to_player > view_distance:
		return false

	var to_player := flat / range_to_player
	var offset := absf(atan2(facing.x * to_player.y - facing.y * to_player.x, facing.dot(to_player)))
	if offset > deg_to_rad(vision_angle_degrees) * 0.5:
		return false

	_sight_query.from = eye
	_sight_query.to = target
	var hit := get_world_3d().direct_space_state.intersect_ray(_sight_query)
	return not hit.is_empty() and hit.collider == _player


func has_detected_player() -> bool:
	return player_visible and sight_seconds >= detection_time


func get_detection_progress() -> float:
	if detection_time <= 0.0:
		return 1.0 if player_visible else 0.0
	return clampf(sight_seconds / detection_time, 0.0, 1.0)


func get_eye_position() -> Vector3:
	return global_position + Vector3(0.0, eye_height, 0.0)


func get_state_name() -> StringName:
	if _machine == null:
		return &""
	return _machine.get_state_name()


func set_destination(spot: Vector3) -> void:
	_agent.target_position = spot


func is_path_finished() -> bool:
	return _agent.is_navigation_finished()


func move_along_path(speed: float, delta: float) -> void:
	var step := _agent.get_next_path_position() - global_position
	step.y = 0.0
	if step.length() < 0.001:
		brake(delta)
		return
	var direction := step.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	turn_towards(Vector2(direction.x, direction.z), delta)


func brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, brake_rate * delta)
	velocity.z = move_toward(velocity.z, 0.0, brake_rate * delta)


func turn_towards(direction: Vector2, delta: float) -> void:
	var current := atan2(facing.x, facing.y)
	var target := atan2(direction.x, direction.y)
	var angle := lerp_angle(current, target, 1.0 - exp(-turn_speed * delta))
	facing = Vector2(sin(angle), cos(angle))
	_apply_facing()


func face_world_spot(spot: Vector3, delta: float) -> void:
	var flat := Vector2(spot.x - global_position.x, spot.z - global_position.z)
	if flat.length() < 0.001:
		return
	turn_towards(flat.normalized(), delta)


func has_arrived_at(spot: Vector3) -> bool:
	return flat_distance(spot, global_position) <= arrive_distance


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func random_navigable_point(around: Vector3, radius: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var reach := sqrt(_rng.randf()) * radius
	var wanted := around + Vector3(sin(angle), 0.0, cos(angle)) * reach
	var map := _agent.get_navigation_map()
	if not map.is_valid():
		return around
	var on_mesh := NavigationServer3D.map_get_closest_point(map, wanted)
	if flat_distance(on_mesh, wanted) > radius:
		return around
	return on_mesh


func random_range(minimum: float, maximum: float) -> float:
	return _rng.randf_range(minimum, maxf(minimum, maximum))


func random_count(minimum: int, maximum: int) -> int:
	return _rng.randi_range(minimum, maxi(minimum, maximum))


func play_animation(animation: StringName) -> void:
	if animation == &"":
		return
	animation_requested.emit(animation)
	if _animator != null and _animator.has_animation(animation):
		_animator.play(animation)


func animation_length(animation: StringName) -> float:
	if animation == &"" or _animator == null or not _animator.has_animation(animation):
		return -1.0
	return _animator.get_animation(animation).length


func play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	sound_requested.emit(stream)
	if _speaker != null:
		_speaker.stream = stream
		_speaker.play()


func _apply_facing() -> void:
	_visual.rotation.y = atan2(-facing.x, -facing.y)
