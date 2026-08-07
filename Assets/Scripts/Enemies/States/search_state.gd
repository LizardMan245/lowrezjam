extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.1, 12.0, 0.1) var speed := 2.6
@export_range(0.5, 10.0, 0.1) var radius := 2.0
@export_range(1, 10) var glances_min := 3
@export_range(1, 10) var glances_max := 4
@export_range(0.0, 5.0, 0.05) var pause := 0.4
@export_range(0.5, 20.0) var leg_timeout := 3.0

var _anchor := Vector3.ZERO
var _glances_left := 0
var _timer := 0.0
var _pause_timer := 0.0


func enter() -> void:
	super()
	_anchor = actor.last_known_player_spot
	_glances_left = actor.random_count(glances_min, glances_max)
	_begin_leg()


func physics_tick(delta: float) -> void:
	if _pause_timer > 0.0:
		actor.brake(delta)
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_finish_leg()
		return

	_timer -= delta
	if actor.is_path_finished() or _timer <= 0.0:
		_pause_timer = pause
		if _pause_timer <= 0.0:
			_finish_leg()
		return

	actor.move_along_path(speed, delta)


func _begin_leg() -> void:
	_pause_timer = 0.0
	_timer = leg_timeout
	actor.set_destination(actor.random_navigable_point(_anchor, radius))


func _finish_leg() -> void:
	_glances_left -= 1
	if _glances_left <= 0:
		go_to_next_state()
		return
	_begin_leg()


func get_search_anchor() -> Vector3:
	return _anchor
