extends "res://Assets/Enemies/StateMachine/enemy_state.gd"

@export_range(0.1, 16.0, 0.1) var minimum_speed := 2.5
@export_range(0.0, 360.0, 1.0) var narrow_to_degrees := 270.0
@export_range(0.5, 30.0, 0.5) var timeout := 6.0
@export var next_state: StringName = &"Search"

var _speed := 0.0
var _timer := 0.0
var _target := Vector3.ZERO
var _start_angle := 360.0
var _total_distance := 0.0


func _init() -> void:
	noise_response = NoiseResponse.IGNORE


func enter() -> void:
	super()
	_speed = maxf(actor.escape_speed, minimum_speed)
	_timer = timeout
	_target = actor.nearest_walkable_point(actor.last_known_player_spot)
	_start_angle = actor.get_vision_angle()
	_total_distance = maxf(actor.flat_distance(_target, actor.global_position), 0.001)
	actor.set_destination(_target)


func physics_tick(delta: float) -> void:
	_timer -= delta
	actor.set_vision_angle(lerpf(_start_angle, narrow_to_degrees, _progress()))

	if actor.is_path_finished() or actor.has_arrived_at(_target) or _timer <= 0.0:
		go_to(next_state)
		return

	actor.move_along_path(_speed, delta)


func _progress() -> float:
	var left := actor.flat_distance(_target, actor.global_position)
	return clampf(1.0 - left / _total_distance, 0.0, 1.0)


func get_speed() -> float:
	return _speed


func get_catch_up_target() -> Vector3:
	return _target
