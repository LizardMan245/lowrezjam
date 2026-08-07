extends "res://Assets/Scripts/Enemies/enemy_state.gd"

@export_range(0.0, 10.0, 0.05) var fallback_duration := 0.9
@export var sound: AudioStream
@export var turn_to_face_player := true
@export var next_state: StringName = &"Chase"

var _timer := 0.0


func enter() -> void:
	super()
	actor.play_sound(sound)
	var animated: float = actor.animation_length(animation)
	_timer = animated if animated > 0.0 else fallback_duration


func physics_tick(delta: float) -> void:
	actor.brake(delta)
	if turn_to_face_player:
		actor.face_world_spot(actor.last_known_player_spot, delta)
	_timer -= delta
	if _timer <= 0.0:
		go_to(next_state)
