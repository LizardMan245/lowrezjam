extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.1, 16.0, 0.1) var minimum_speed := 2.5
@export_range(1.0, 30.0, 0.5) var probe_distance := 8.0
@export_range(0.5, 30.0, 0.5) var timeout := 7.0
@export_range(0.5, 10.0, 0.1) var reprobe_interval := 2.0
@export var next_state: StringName = &"Scan"

var _speed := 0.0
var _timer := 0.0
var _reprobe_timer := 0.0
var _target := Vector3.ZERO


func _init() -> void:
	noise_response = NoiseResponse.REDIRECT


func enter() -> void:
	super()
	_speed = maxf(actor.escape_speed, minimum_speed)
	_timer = timeout
	_probe_along_escape_route()


func on_noise(_strength: float) -> void:
	_aim_at(actor.noise_spot)


func physics_tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		go_to(next_state)
		return

	_reprobe_timer -= delta
	if actor.is_path_finished() or _reprobe_timer <= 0.0:
		_probe_along_escape_route()

	actor.move_along_path(_speed, delta)


func _probe_along_escape_route() -> void:
	var heading := actor.last_known_player_heading
	if heading.length() < 0.001:
		heading = actor.facing
	var ahead := actor.global_position + Vector3(heading.x, 0.0, heading.y) * probe_distance
	_aim_at(ahead)


func _aim_at(spot: Vector3) -> void:
	_target = actor.nearest_walkable_point(spot)
	_reprobe_timer = reprobe_interval
	actor.set_destination(_target)


func get_search_spot() -> Vector3:
	return _target
