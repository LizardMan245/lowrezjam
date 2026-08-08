extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.1, 12.0, 0.1) var speed := 2.6
@export_range(0.5, 10.0, 0.1) var radius := 2.0
@export_range(1, 10) var segments_min := 3
@export_range(1, 10) var segments_max := 4
@export_range(0.0, 5.0, 0.05) var pause_time := 0.4
@export_range(0.5, 20.0) var segment_timeout := 3.0

var _search_spot := Vector3.ZERO
var _segments_left := 0
var _timer := 0.0
var _pause_timer := 0.0


func enter() -> void:
	super()
	_search_spot = actor.last_known_player_spot
	_segments_left = actor.random_count(segments_min, segments_max)
	_start_segment()


func physics_tick(delta: float) -> void:
	if _pause_timer > 0.0:
		actor.brake(delta)
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_end_segment()
		return

	_timer -= delta
	if actor.is_path_finished() or _timer <= 0.0:
		_pause_timer = pause_time
		if _pause_timer <= 0.0:
			_end_segment()
		return

	actor.move_along_path(speed, delta)


func _start_segment() -> void:
	_pause_timer = 0.0
	_timer = segment_timeout
	actor.set_destination(actor.random_walkable_point(_search_spot, radius))


func _end_segment() -> void:
	_segments_left -= 1
	if _segments_left <= 0:
		go_to_next_state()
		return
	_start_segment()


func get_search_spot() -> Vector3:
	return _search_spot
