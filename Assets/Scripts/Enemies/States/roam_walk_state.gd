extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.1, 12.0, 0.1) var speed := 1.6
@export_range(1.0, 30.0) var radius := 8.0
@export_range(1.0, 60.0) var timeout := 8.0

var _timer := 0.0


func enter() -> void:
	super()
	var spot: Vector3 = actor.random_navigable_point(actor.global_position, radius)
	if actor.has_arrived_at(spot):
		_timer = 0.0
		return
	_timer = timeout
	actor.set_destination(spot)


func physics_tick(delta: float) -> void:
	_timer -= delta
	if actor.is_path_finished() or _timer <= 0.0:
		go_to_next_state()
		return
	actor.move_along_path(speed, delta)
