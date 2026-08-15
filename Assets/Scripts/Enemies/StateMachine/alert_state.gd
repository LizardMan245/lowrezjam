extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.0, 10.0, 0.05) var default_duration := 0.9
@export var sound: AudioStream
@export var turn_to_face_player := true
@export var next_state: StringName = &"Chase"

@export_group("Re-lock")
@export_range(0.0, 4.0, 0.05) var relock_duration := 0.25
@export var relock_sound: AudioStream
@export var relock_from_states: Array[StringName] = [&"CatchUp", &"Search", &"Scan"]

var _timer := 0.0


func _init() -> void:
	noise_response = NoiseResponse.IGNORE


func enter() -> void:
	super()
	if _is_relock():
		actor.play_sound(relock_sound if relock_sound != null else sound)
		_timer = relock_duration
		return
	actor.play_sound(sound)
	var animated: float = actor.animation_length(animation)
	_timer = animated if animated > 0.0 else default_duration


func physics_tick(delta: float) -> void:
	actor.brake(delta)
	if turn_to_face_player:
		actor.face_spot(actor.last_known_player_spot, delta)
	_timer -= delta
	if _timer <= 0.0:
		go_to(next_state)


func _is_relock() -> bool:
	return relock_from_states.has(machine.get_previous_state_name())
