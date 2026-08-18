extends "res://Assets/Enemies/StateMachine/enemy_state.gd"

@export var sound: AudioStream
@export_range(0.1, 12.0, 0.1) var min_speed := 1.8
@export_range(0.1, 12.0, 0.1) var max_speed := 2.8
@export_range(0.0, 4.0, 0.05) var turn_time := 0.45
@export_range(0.0, 60.0, 1.0) var turn_tolerance_degrees := 25.0
@export_range(1.0, 60.0) var timeout := 9.0

var _target := Vector3.ZERO
var _timer := 0.0
var _turn_timer := 0.0
var _speed := 0.0


func _init() -> void:
	noise_response = NoiseResponse.IGNORE


func enter() -> void:
	super()
	actor.play_sound(sound)
	_target = actor.nearest_walkable_point(actor.noise_spot)
	_speed = actor.random_range(min_speed, max_speed)
	_turn_timer = turn_time
	_timer = timeout
	actor.set_destination(_target)


func unsuspend() -> void:
	super()
	actor.set_destination(_target)


func physics_tick(delta: float) -> void:
	_timer -= delta

	if _turn_timer > 0.0:
		_turn_timer -= delta
		actor.brake(delta)
		actor.face_spot(_target, delta)
		if _turn_timer > 0.0 and not actor.is_facing(_target, turn_tolerance_degrees):
			return
		_turn_timer = 0.0

	if actor.is_path_finished() or _timer <= 0.0:
		go_to_next_state()
		return
	actor.move_along_path(_speed, delta)


func get_investigate_target() -> Vector3:
	return _target
