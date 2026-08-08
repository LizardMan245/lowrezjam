extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export var sound: AudioStream
@export_range(0.0, 20.0, 0.1) var min_time := 0.8
@export_range(0.0, 20.0, 0.1) var max_time := 3.5

var _timer := 0.0


func enter() -> void:
	super()
	actor.play_sound(sound)
	_timer = actor.random_range(min_time, max_time)


func physics_tick(delta: float) -> void:
	actor.brake(delta)
	_timer -= delta
	if _timer <= 0.0:
		go_to_next_state()
