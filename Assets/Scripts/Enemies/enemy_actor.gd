extends CharacterBody3D

const NAVIGATION_WAIT_FRAMES := 120
const NAVIGATION_SNAP_LIMIT := 4.0
const UNLIMITED_VIEW_DISTANCE := 1000.0

signal state_changed(previous: StringName, current: StringName)
signal player_detected
signal player_lost
signal noise_noticed(spot: Vector3, strength: float)
signal animation_requested(animation: StringName)
signal sound_requested(stream: AudioStream)

@export_group("Senses")
@export_range(5.0, 360.0) var vision_angle_degrees := 70.0
@export_range(1.0, 40.0) var view_distance := 12.0
@export_range(0.0, 4.0) var eye_height := 0.6
@export_flags_3d_physics var sight_mask := 1
@export_range(0.0, 10.0, 0.05) var detection_time := 0.5
@export_range(0.0, 10.0, 0.05) var detection_decay_rate := 1.5
@export_range(0.0, 1.0, 0.05) var peripheral_fill_scale := 0.25
@export_range(0.2, 6.0, 0.1) var peripheral_falloff := 1.6

@export_group("Ram sense")
@export var ram_sense := false
@export_range(0.0, 20.0, 0.5) var ram_sense_floor := 2.0

@export_group("Hearing")
@export_range(0.0, 3.0, 0.05) var hearing_range_scale := 1.0
@export_range(0.0, 8.0, 0.05) var hearing_sensitivity := 1.4
@export_range(0.0, 1.0, 0.05) var wall_muffle := 0.4
@export_range(0.0, 1.0, 0.05) var loud_noise_threshold := 0.35
@export_range(0.0, 90.0, 1.0) var noise_swing_degrees := 45.0
@export_range(0.0, 10.0, 0.1) var notice_cooldown := 1.5

@export_group("Movement")
@export_range(1.0, 30.0) var turn_speed := 6.0
@export_range(1.0, 60.0) var brake_rate := 14.0
@export_range(0.1, 3.0, 0.05) var arrive_distance := 0.6
@export_range(0.0, 4.0, 0.05) var repath_distance := 0.6

@export_group("Roaming")
@export_range(1, 32) var spots_to_try := 12
@export_range(0.0, 4.0, 0.1) var facing_bias := 1.2
@export_range(0.0, 4.0, 0.1) var distance_bias := 0.5
@export_range(0.0, 4.0, 0.1) var backtrack_penalty := 1.6
@export_range(0.0, 4.0, 0.1) var revisit_penalty := 1.1
@export_range(0.0, 8.0, 0.1) var roam_pick_sharpness := 1.5
@export var roam_needs_line_of_sight := true
@export_range(1.0, 4.0, 0.1) var max_detour := 1.7
@export_range(0.0, 3.0, 0.05) var roam_clearance := 0.85
@export_range(0.5, 8.0, 0.5) var memory_cell_size := 2.0
@export_range(1.0, 180.0, 1.0) var memory_seconds := 45.0

var facing := Vector2(0.0, 1.0)
var player_visible := false
var truly_visible := false
var ram_sensed := false
var sight_focus := -1.0
var last_known_player_spot := Vector3.ZERO
var last_known_player_heading := Vector2(0.0, 1.0)
var escape_speed := 0.0
var sight_seconds := 0.0
var last_heard_spot := Vector3.ZERO
var heard_loudness := 0.0
var noise_spot := Vector3.ZERO
var noise_strength := 0.0

var _player: Node3D
var _agent: NavigationAgent3D
var _machine
var _visual: Node3D
var _animator: AnimationPlayer
var _speaker: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _sight_query := PhysicsRayQueryParameters3D.new()
var _room_query := PhysicsShapeQueryParameters3D.new()
var _room_shape := SphereShape3D.new()
var _detected_last_frame := false
var _active_vision_angle := 70.0
var _active_view_distance := 12.0
var _detection_rate := 1.0
var _last_move_speed := 0.0
var _pending_noise_spot := Vector3.ZERO
var _pending_noise_strength := 0.0
var _has_pending_noise := false
var _notice_cooldown_left := 0.0
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
		push_warning("enemy is missing a NavigationAgent3D, StateMachine or visual node")
		return
	if _player == null:
		push_warning("no player found, the enemy will just walk around")

	_rng.randomize()
	_sight_query.collision_mask = sight_mask
	_sight_query.exclude = [get_rid()]
	_last_roam_spot = global_position
	_came_from = -facing
	reset_senses()
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
	push_warning("the navigation map did not load in time")


func _navigation_is_ready() -> bool:
	var map := _agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	return flat_distance(NavigationServer3D.map_get_closest_point(map, global_position), global_position) < NAVIGATION_SNAP_LIMIT


func reset_senses() -> void:
	_active_vision_angle = vision_angle_degrees
	_active_view_distance = view_distance
	_detection_rate = 1.0


func set_vision_angle(degrees: float) -> void:
	_active_vision_angle = clampf(degrees, 0.0, 360.0)


func set_view_distance(distance: float) -> void:
	_active_view_distance = maxf(distance, 0.0)


func set_detection_rate(rate: float) -> void:
	_detection_rate = maxf(rate, 0.0)


func get_vision_angle() -> float:
	return _active_vision_angle


func get_view_distance() -> float:
	return _active_view_distance


func get_base_vision_angle() -> float:
	return vision_angle_degrees


func get_base_view_distance() -> float:
	return view_distance


func get_hearing_radius() -> float:
	return view_distance * hearing_range_scale


func _update_senses(delta: float) -> void:
	var was_visible := player_visible
	var measured := _measure_sight()
	truly_visible = measured >= 0.0
	ram_sensed = ram_sense and _ram_sense_reaches_player()
	sight_focus = 1.0 if (ram_sensed and not truly_visible) else measured
	player_visible = sight_focus >= 0.0

	if player_visible:
		last_known_player_spot = _player.global_position
		last_known_player_heading = _player_heading()
		sight_seconds = minf(sight_seconds + delta * _sight_fill_rate() * _detection_rate, detection_time)
	else:
		if was_visible:
			escape_speed = _last_move_speed
			player_lost.emit()
		sight_seconds = maxf(sight_seconds - delta * detection_decay_rate, 0.0)

	_update_hearing(delta)

	var detected := has_detected_player()
	if detected and not _detected_last_frame:
		player_detected.emit()
	_detected_last_frame = detected


func _player_heading() -> Vector2:
	var body := _player as CharacterBody3D
	if body != null:
		var travel := Vector2(body.velocity.x, body.velocity.z)
		if travel.length() > 0.05:
			return travel.normalized()
	var aim = _player.get("facing")
	if aim is Vector2 and aim.length() > 0.001:
		return aim
	return last_known_player_heading


func _sight_fill_rate() -> float:
	var centred := pow(clampf(sight_focus, 0.0, 1.0), peripheral_falloff)
	return lerpf(peripheral_fill_scale, 1.0, centred)


func _measure_sight() -> float:
	if _player == null:
		return -1.0

	var eye := get_eye_position()
	var target := Vector3(_player.global_position.x, eye.y, _player.global_position.z)
	var flat := Vector2(target.x - eye.x, target.z - eye.z)
	var range_to_player := flat.length()
	if range_to_player < 0.001 or range_to_player > _active_view_distance:
		return -1.0

	var to_player := flat / range_to_player
	var offset := absf(atan2(facing.x * to_player.y - facing.y * to_player.x, facing.dot(to_player)))
	var half := deg_to_rad(_active_vision_angle) * 0.5
	if offset > half:
		return -1.0

	_sight_query.from = eye
	_sight_query.to = target
	var hit := get_world_3d().direct_space_state.intersect_ray(_sight_query)
	if hit.is_empty() or hit.collider != _player:
		return -1.0
	if half < 0.001:
		return 1.0
	return 1.0 - offset / half


func _update_hearing(delta: float) -> void:
	_notice_cooldown_left = maxf(_notice_cooldown_left - delta, 0.0)

	heard_loudness = get_noise_loudness()
	if heard_loudness <= 0.0:
		return
	last_heard_spot = _player.global_position

	if _has_pending_noise or _notice_cooldown_left > 0.0:
		return
	if _rng.randf() >= heard_loudness * hearing_sensitivity * delta:
		return

	_notice_cooldown_left = notice_cooldown
	_pending_noise_strength = heard_loudness
	_pending_noise_spot = swing_spot(last_heard_spot, heard_loudness, noise_swing_degrees)
	_has_pending_noise = true
	noise_noticed.emit(_pending_noise_spot, _pending_noise_strength)


func get_noise_loudness() -> float:
	if _player == null:
		return 0.0
	var radius := get_hearing_radius()
	if radius <= 0.0:
		return 0.0
	var output: float = _player.get_noise_level() if _player.has_method("get_noise_level") else 0.0
	if output <= 0.0:
		return 0.0
	var distance := flat_distance(_player.global_position, global_position)
	if distance >= radius:
		return 0.0
	var reach := 1.0 - distance / radius
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


func has_noise_cue() -> bool:
	return _has_pending_noise


func take_noise_cue() -> float:
	_has_pending_noise = false
	noise_spot = _pending_noise_spot
	noise_strength = _pending_noise_strength
	return noise_strength


func discard_noise_cue() -> void:
	_has_pending_noise = false


func noise_is_loud(strength: float) -> bool:
	return strength >= loud_noise_threshold


func swing_spot(spot: Vector3, strength: float, max_error_degrees: float) -> Vector3:
	var to := Vector2(spot.x - global_position.x, spot.z - global_position.z)
	if to.length() < 0.001:
		return spot
	var error := deg_to_rad(max_error_degrees) * (1.0 - clampf(strength, 0.0, 1.0))
	var swung := to.rotated(_rng.randf_range(-error, error))
	return global_position + Vector3(swung.x, 0.0, swung.y)


func can_see_player() -> bool:
	return _measure_sight() >= 0.0


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


func ram_sense_radius() -> float:
	if not ram_sense or _player == null:
		return 0.0
	if _player.has_method("get_ram_radius"):
		return maxf(ram_sense_floor, _player.get_ram_radius())
	return ram_sense_floor


func _ram_sense_reaches_player() -> bool:
	return _player != null and flat_distance(global_position, _player.global_position) <= ram_sense_radius()


func get_player_spot() -> Vector3:
	return _player.global_position if _player != null else global_position


func get_eye_position() -> Vector3:
	return global_position + Vector3(0.0, eye_height, 0.0)


func get_state_name() -> StringName:
	if _machine == null:
		return &""
	return _machine.get_state_name()


func set_destination(spot: Vector3) -> void:
	if flat_distance(_agent.target_position, spot) < repath_distance:
		return
	_agent.target_position = spot


func is_path_finished() -> bool:
	return _agent.is_navigation_finished()


func move_along_path(speed: float, delta: float) -> void:
	_last_move_speed = speed
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


func is_facing(spot: Vector3, tolerance_degrees: float) -> bool:
	var flat := Vector2(spot.x - global_position.x, spot.z - global_position.z)
	if flat.length() < 0.001:
		return true
	return absf(facing.angle_to(flat.normalized())) <= deg_to_rad(tolerance_degrees)


func has_arrived_at(spot: Vector3) -> bool:
	return flat_distance(spot, global_position) <= arrive_distance


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func nearest_walkable_point(spot: Vector3) -> Vector3:
	var map := _agent.get_navigation_map()
	if not map.is_valid():
		return spot
	return NavigationServer3D.map_get_closest_point(map, spot)


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

	var in_sight: Array = []
	var reachable: Array = []
	for _try in spots_to_try:
		var spot := random_walkable_point(around, radius)
		if has_arrived_at(spot) or not has_room_at(spot) or not _path_is_direct(spot):
			continue
		var scored := [_score_spot(spot, radius), spot]
		reachable.append(scored)
		if has_clear_line_to(spot):
			in_sight.append(scored)

	var pool: Array = in_sight if roam_needs_line_of_sight and not in_sight.is_empty() else reachable
	if pool.is_empty():
		for _retry in spots_to_try:
			var loose := random_walkable_point(around, radius)
			if has_room_at(loose):
				return loose
		return random_walkable_point(around, radius)
	return _pick_weighted(pool)


func _pick_weighted(pool: Array) -> Vector3:
	var best: float = pool[0][0]
	for scored in pool:
		best = maxf(best, scored[0])

	var weights: Array[float] = []
	var total := 0.0
	for scored in pool:
		var weight: float = exp((scored[0] - best) * roam_pick_sharpness)
		weights.append(weight)
		total += weight

	var roll := _rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i][1]
	return pool[pool.size() - 1][1]


func _update_came_from(around: Vector3) -> void:
	var back := Vector2(_last_roam_spot.x - around.x, _last_roam_spot.z - around.z)
	_came_from = back.normalized() if back.length() > 0.001 else -facing
	_last_roam_spot = around


func _score_spot(spot: Vector3, radius: float) -> float:
	var to := Vector2(spot.x - global_position.x, spot.z - global_position.z)
	var distance := to.length()
	if distance < 0.001:
		return -INF
	var direction := to / distance
	var score := facing_bias * facing.dot(direction)
	score += distance_bias * clampf(distance / maxf(radius, 0.001), 0.0, 1.0)
	score -= backtrack_penalty * maxf(_came_from.dot(direction), 0.0)
	score -= revisit_penalty * _visit_amount(spot)
	return score


func has_room_at(spot: Vector3) -> bool:
	if roam_clearance <= 0.0:
		return true
	_room_shape.radius = roam_clearance
	_room_query.shape = _room_shape
	_room_query.collision_mask = collision_mask
	_room_query.exclude = [get_rid()]
	_room_query.transform = Transform3D(Basis.IDENTITY, spot + Vector3(0.0, roam_clearance + 0.1, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


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
