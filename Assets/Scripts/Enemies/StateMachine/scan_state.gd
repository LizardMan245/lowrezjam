extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export var sound: AudioStream
@export_range(1, 8) var glances_min := 2
@export_range(1, 8) var glances_max := 3
@export_range(0.1, 5.0, 0.05) var hold_time := 0.9
@export_range(10.0, 180.0, 1.0) var sweep_degrees := 110.0
@export_range(1.0, 20.0, 0.5) var look_distance := 4.0

var _glances_left := 0
var _timer := 0.0
var _target := Vector3.ZERO


func _init() -> void:
	noise_response = NoiseResponse.REDIRECT


func enter() -> void:
	super()
	actor.play_sound(sound)
	_glances_left = actor.random_count(glances_min, glances_max)
	_look_somewhere_new()


func on_noise(_strength: float) -> void:
	_target = actor.noise_spot
	_timer = hold_time


func physics_tick(delta: float) -> void:
	actor.brake(delta)
	actor.face_spot(_target, delta)
	_timer -= delta
	if _timer > 0.0:
		return

	_glances_left -= 1
	if _glances_left <= 0:
		go_to_next_state()
		return
	_look_somewhere_new()


func _look_somewhere_new() -> void:
	var swing := deg_to_rad(actor.random_range(-sweep_degrees, sweep_degrees))
	var direction := actor.facing.rotated(swing)
	_target = actor.global_position + Vector3(direction.x, 0.0, direction.y) * look_distance
	_timer = hold_time


func get_scan_target() -> Vector3:
	return _target
