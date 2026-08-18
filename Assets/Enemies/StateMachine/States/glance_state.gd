extends "res://Assets/Enemies/StateMachine/enemy_state.gd"

@export_range(0.0, 4.0, 0.05) var hold_time := 0.8
@export var sound: AudioStream

var _timer := 0.0
var _target := Vector3.ZERO


func _init() -> void:
	noise_response = NoiseResponse.IGNORE


func enter() -> void:
	super()
	actor.play_sound(sound)
	_target = actor.noise_spot
	_timer = hold_time


func physics_tick(delta: float) -> void:
	actor.brake(delta)
	actor.face_spot(_target, delta)
	_timer -= delta
	if _timer <= 0.0:
		machine.resume_previous()


func get_glance_target() -> Vector3:
	return _target
