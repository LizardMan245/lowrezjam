extends "res://Assets/Enemies/StateMachine/enemy_state.gd"

@export var sound: AudioStream
@export_range(0.1, 8.0, 0.1) var speed := 1.1
@export_range(0.5, 20.0, 0.5) var step_distance := 6.0
@export_range(0.1, 8.0, 0.1) var repick_seconds := 1.5
@export_range(0.0, 6.0, 0.1) var wander_spread := 2.5
@export var seen_state: StringName = &"Chase"
@export var lost_state: StringName = &"RoamWalk"

var _timer := 0.0


func _init() -> void:
	noise_response = NoiseResponse.IGNORE
	interrupt_on_detection = false


func enter() -> void:
	super()
	actor.play_sound(sound)
	_aim()


func unsuspend() -> void:
	super()
	_aim()


func physics_tick(delta: float) -> void:
	if actor.truly_visible:
		go_to(seen_state)
		return
	if not actor.ram_sensed:
		go_to(lost_state)
		return

	_timer -= delta
	if _timer <= 0.0 or actor.is_path_finished():
		_aim()
	actor.move_along_path(speed, delta)


func _aim() -> void:
	_timer = repick_seconds
	var here: Vector3 = actor.global_position
	var step := actor.get_player_spot() - here
	step.y = 0.0
	if step.length() > step_distance:
		step = step.normalized() * step_distance
	var drift := Vector3(actor.random_range(-wander_spread, wander_spread), 0.0, actor.random_range(-wander_spread, wander_spread))
	actor.set_destination(actor.nearest_walkable_point(here + step + drift))
