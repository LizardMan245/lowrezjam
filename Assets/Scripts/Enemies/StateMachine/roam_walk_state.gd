extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export var sound: AudioStream
@export_range(0.1, 12.0, 0.1) var min_speed := 1.6
@export_range(0.1, 12.0, 0.1) var max_speed := 2.5
@export_range(1.0, 60.0) var timeout := 8.0

var _destination := Vector3.ZERO
var _timer := 0.0
var random_speed := 0.0


func enter() -> void:
	super()
	actor.play_sound(sound)
	_destination = actor.pick_roam_target(actor.global_position, actor.get_base_view_distance())
	random_speed = actor.random_range(min_speed, max_speed)
	if actor.has_arrived_at(_destination):
		_timer = 0.0
		return
	_timer = timeout
	actor.set_destination(_destination)


func unsuspend() -> void:
	super()
	actor.set_destination(_destination)


func physics_tick(delta: float) -> void:
	_timer -= delta
	if actor.is_path_finished() or _timer <= 0.0:
		go_to_next_state()
		return
	actor.move_along_path(random_speed, delta)


func get_destination() -> Vector3:
	return _destination
