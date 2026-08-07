extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.0, 20.0, 0.1) var minimum_time := 0.8
@export_range(0.0, 20.0, 0.1) var maximum_time := 3.5

var _timer := 0.0


func enter() -> void:
	super()
	_timer = actor.random_range(minimum_time, maximum_time)


func physics_tick(delta: float) -> void:
	actor.brake(delta)
	_timer -= delta
	if _timer <= 0.0:
		go_to_next_state()
