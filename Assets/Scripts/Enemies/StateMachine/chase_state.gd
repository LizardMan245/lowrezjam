extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.1, 16.0, 0.1) var start_speed := 2.4
@export_range(0.1, 16.0, 0.1) var top_speed := 5.5
@export_range(0.1, 20.0, 0.1) var acceleration := 0.9
@export_range(0.1, 20.0, 0.1) var give_up_time := 4.0
@export var lost_state: StringName = &"Search"

var _speed := 0.0
var _give_up_timer := 0.0


func _init() -> void:
	interrupt_on_noise = false


func enter() -> void:
	super()
	_speed = start_speed
	_give_up_timer = give_up_time


func physics_tick(delta: float) -> void:
	_speed = move_toward(_speed, top_speed, acceleration * delta)
	actor.set_destination(actor.last_known_player_spot)

	if actor.player_visible:
		_give_up_timer = give_up_time
	else:
		_give_up_timer -= delta
		if _give_up_timer <= 0.0 or actor.has_arrived_at(actor.last_known_player_spot):
			go_to(lost_state)
			return

	actor.move_along_path(_speed, delta)


func get_speed() -> float:
	return _speed
