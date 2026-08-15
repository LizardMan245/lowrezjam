extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.1, 16.0, 0.1) var start_speed := 3.2
@export_range(0.1, 16.0, 0.1) var top_speed := 4.6
@export_range(0.1, 20.0, 0.1) var acceleration := 0.9
@export_range(0.0, 4.0, 0.05) var lost_grace := 0.2
@export var lost_state: StringName = &"CatchUp"

var _speed := 0.0
var _grace := 0.0


func _init() -> void:
	noise_response = NoiseResponse.IGNORE


func enter() -> void:
	super()
	_speed = start_speed
	_grace = lost_grace


func physics_tick(delta: float) -> void:
	_speed = move_toward(_speed, top_speed, acceleration * delta)

	if actor.player_visible:
		_grace = lost_grace
		actor.set_destination(actor.last_known_player_spot)
	else:
		_grace -= delta
		if _grace <= 0.0:
			go_to(lost_state)
			return

	actor.move_along_path(_speed, delta)


func get_speed() -> float:
	return _speed
