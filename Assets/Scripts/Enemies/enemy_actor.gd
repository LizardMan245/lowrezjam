extends CharacterBody3D

const NAVIGATION_WAIT_FRAMES := 120
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

@export_group("Hearing")
@export_range(0.0, 40.0) var hearing_radius := 12.0
@export_range(0.0, 8.0, 0.05) var hearing_sensitivity := 1.4
@export_range(0.0, 1.0, 0.05) var wall_muffle := 0.4
@export_range(0.0, 4.0, 0.05) var noise_fade_rate := 0.35
@export_range(0.0, 4.0, 0.05) var glance_rate := 0.9
@export_range(0.0, 10.0, 0.1) var glance_cooldown := 2.0

@export_group("Movement")
@export_range(1.0, 30.0) var turn_speed := 6.0
@export_range(1.0, 60.0) var brake_rate := 14.0
@export_range(0.1, 3.0, 0.05) var arrive_distance := 0.6

@export_group("Roaming")
@export_range(1, 32) var spots_to_try := 12
@export_range(0.0, 4.0, 0.1) var facing_bias := 1.2
@export_range(0.0, 4.0, 0.1) var backtrack_penalty := 1.6
@export_range(0.0, 4.0, 0.1) var revisit_penalty := 1.1
@export var roam_needs_line_of_sight := true
@export_range(1.0, 4.0, 0.1) var max_detour := 1.7
@export_range(0.5, 8.0, 0.5) var memory_cell_size := 2.0
@export_range(1.0, 180.0, 1.0) var memory_seconds := 45.0

var facing := Vector2(0.0, 1.0)
var player_visible := false
var last_known_player_spot := Vector3.ZERO
var sight_seconds := 0.0
var noise_level := 0.0
var last_heard_spot := Vector3.ZERO
var heard_loudness := 0.0

var _player: Node3D
var _agent: NavigationAgent3D
var _machine
var _visual: Node3D
var _animator: AnimationPlayer
var _speaker: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _sight_query := PhysicsRayQueryParameters3D.new()
var _detected_last_frame := false
var _glance_pending := false
var _glance_cooldown_left := 0.0
var _visited := {}
var _last_roam_spot := Vector3.ZERO
var _came_from := Vector2.ZERO


func _ready() -> void:
	set_physics_process(false)
	_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_machine = get_node_or_null("StateMachine")
	_visual = get_node_or_null("Visual") as Node3D
	_animator = get_node_or_null("AnimationPlayer") as AnimationPlayer
	_speaker = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	_player = get_tree().get_first_node_in_group("player") as Node3D

	if _agent == null or _machine == null or _visual == null:
		push_warning("Enemy is missing a NavigationAgent3D, StateMachine or Visual node.")
		return
	if _player == null:
		push_warning("No player found, so the enemy will just walk around.")

	_rng.randomize()
	_sight_query.collision_mask = sight_mask
	_sight_query.exclude = [get_rid()]
	_last_roam_spot = global_position
	_came_from = -facing
	_apply_facing()

	_machine.setup(self)
	_machine.state_changed.connect(_on_state_changed)
	await _wait_for_navigation()
	_machine.start()
	set_physics_process(true)


func _on_state_changed(previous: StringName, current: StringName) -> void:
	state_changed.emit(previous, current)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_update_senses(delta)
	_remember_cell()
	_forget_old_cells(delta)
	_machine.physics_tick(delta)
	move_and_slide()


func _wait_for_navigation() -> void:
	for _frame in NAVIGATION_WAIT_FRAMES:
		if _navigation_is_ready():
			return
		await get_tree().physics_frame
	push_warning("The navigation map did not load in time.")


func _navigation_is_ready() -> bool:
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

	_update_hearing(delta)

	var detected := has_detected_player()
	if detected and not _detected_last_frame:
		player_detected.emit()
	_detected_last_frame = detected


func _update_hearing(delta: float) -> void:
	var loudness := get_noise_loudness()
	if loudness > 0.0:
		last_heard_spot = _player.global_position
		heard_loudness = loudness
		noise_level = minf(noise_level + loudness * hearing_sensitivity * delta, 1.0)
	else:
		noise_level = maxf(noise_level - noise_fade_rate * delta, 0.0)

	_glance_cooldown_left = maxf(_glance_cooldown_left - delta, 0.0)
	if _glance_cooldown_left > 0.0 or _glance_pending:
		return
	if _rng.randf() < glance_rate * noise_level * delta:
		_glance_pending = true


func get_noise_loudness() -> float:
	if _player == null or hearing_radius <= 0.0:
		return 0.0
	var source = _player
	var output: float = source.get_noise_level() if source.has_method("get_noise_level") else 0.0
	if output <= 0.0:
		return 0.0
	var distance := flat_distance(_player.global_position, global_position)
	if distance >= hearing_radius:
		return 0.0
	var reach := 1.0 - distance / hearing_radius
	var loudness := output * reach * reach
	if _wall_blocks_sound():
		loudness *= wall_muffle
	return loudness


func _wall_blocks_sound() -> bool:
	var eye := get_eye_position()
	_sight_query.from = eye
	_sight_query.to = Vector3(_player.global_position.x, eye.y, _player.global_position.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(_sight_query)
	return not hit.is_empty() and hit.collider != _player


func wants_to_glance() -> bool:
	return _glance_pending


func use_glance() -> void:
	_glance_pending = false
	_glance_cooldown_left = glance_cooldown
	noise_level *= 0.3


func guess_noise_spot(max_error_degrees: float) -> Vector3:
	var to := Vector2(last_heard_spot.x - global_position.x, last_heard_spot.z - global_position.z)
	if to.length() < 0.001:
		return last_heard_spot
	var error := deg_to_rad(max_error_degrees) * (1.0 - clampf(heard_loudness, 0.0, 1.0))
	var swung := to.rotated(_rng.randf_range(-error, error))
	return global_position + Vector3(swung.x, 0.0, swung.y)


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


func has_clear_line_to(spot: Vector3) -> bool:
	var eye := get_eye_position()
	_sight_query.from = eye
	_sight_query.to = Vector3(spot.x, eye.y, spot.z)
	return get_world_3d().direct_space_state.intersect_ray(_sight_query).is_empty()


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


func face_spot(spot: Vector3, delta: float) -> void:
	var flat := Vector2(spot.x - global_position.x, spot.z - global_position.z)
	if flat.length() < 0.001:
		return
	turn_towards(flat.normalized(), delta)


func has_arrived_at(spot: Vector3) -> bool:
	return flat_distance(spot, global_position) <= arrive_distance


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func random_walkable_point(around: Vector3, radius: float) -> Vector3:
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


func pick_roam_target(around: Vector3, radius: float) -> Vector3:
	_update_came_from(around)

	var visible: Array = []
	var reachable: Array = []
	for _try in spots_to_try:
		var spot := random_walkable_point(around, radius)
		if has_arrived_at(spot) or not _path_is_direct(spot):
			continue
		var scored := [_score_spot(spot), spot]
		reachable.append(scored)
		if has_clear_line_to(spot):
			visible.append(scored)

	var pool: Array = visible if roam_needs_line_of_sight and not visible.is_empty() else reachable
	if pool.is_empty():
		return random_walkable_point(around, radius)

	pool.sort_custom(func(a, b): return a[0] > b[0])
	return pool[_rng.randi_range(0, mini(2, pool.size() - 1))][1]


func _update_came_from(around: Vector3) -> void:
	var back := Vector2(_last_roam_spot.x - around.x, _last_roam_spot.z - around.z)
	_came_from = back.normalized() if back.length() > 0.001 else -facing
	_last_roam_spot = around


func _score_spot(spot: Vector3) -> float:
	var to := Vector2(spot.x - global_position.x, spot.z - global_position.z)
	var distance := to.length()
	if distance < 0.001:
		return -INF
	var direction := to / distance
	var score := facing_bias * facing.dot(direction)
	score -= backtrack_penalty * maxf(_came_from.dot(direction), 0.0)
	score -= revisit_penalty * _visit_amount(spot)
	return score


func _path_is_direct(spot: Vector3) -> bool:
	var straight := flat_distance(spot, global_position)
	if straight < 0.001:
		return false
	var map := _agent.get_navigation_map()
	if not map.is_valid():
		return true
	var path := NavigationServer3D.map_get_path(map, global_position, spot, true)
	if path.size() < 2:
		return false
	var travelled := 0.0
	for i in range(1, path.size()):
		travelled += path[i].distance_to(path[i - 1])
	return travelled <= straight * max_detour


func _cell_at(spot: Vector3) -> Vector2i:
	return Vector2i(floori(spot.x / memory_cell_size), floori(spot.z / memory_cell_size))


func _remember_cell() -> void:
	_visited[_cell_at(global_position)] = memory_seconds


func _forget_old_cells(delta: float) -> void:
	for cell in _visited.keys():
		var left: float = _visited[cell] - delta
		if left <= 0.0:
			_visited.erase(cell)
		else:
			_visited[cell] = left


func _visit_amount(spot: Vector3) -> float:
	return _visited.get(_cell_at(spot), 0.0) / memory_seconds


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
