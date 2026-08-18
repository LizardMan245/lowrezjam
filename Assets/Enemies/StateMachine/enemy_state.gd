extends Node

const EnemyActor = preload("res://Assets/Enemies/Scripts/enemy_actor.gd")

enum NoiseResponse {
	IGNORE,
	TIERED,
	REDIRECT,
}

@export var animation: StringName = &""
@export var interrupt_on_detection := true
@export var detection_state: StringName = &"Alert"

@export_group("Hearing")
@export var noise_response: NoiseResponse = NoiseResponse.TIERED
@export var glance_state: StringName = &"Glance"
@export var investigate_state: StringName = &"Investigate"

@export_group("Senses")
@export_range(0.0, 360.0, 1.0) var vision_angle_override := 0.0
@export_range(0.0, 60.0, 0.5) var view_distance_override := 0.0
@export var unlimited_view_distance := false
@export_range(0.0, 8.0, 0.05) var detection_rate := 1.0

@export_group("Flow")
@export var next_states: Array[StringName] = []
@export var next_state_weights: Array[float] = []

var actor: EnemyActor
var machine


func setup(owner_actor: EnemyActor, owner_machine) -> void:
	actor = owner_actor
	machine = owner_machine


func apply_senses() -> void:
	actor.set_vision_angle(vision_angle_override if vision_angle_override > 0.0 else actor.get_base_vision_angle())
	if unlimited_view_distance:
		actor.set_view_distance(EnemyActor.UNLIMITED_VIEW_DISTANCE)
	elif view_distance_override > 0.0:
		actor.set_view_distance(view_distance_override)
	else:
		actor.set_view_distance(actor.get_base_view_distance())
	actor.set_detection_rate(detection_rate)


func enter() -> void:
	actor.play_animation(animation)


func exit() -> void:
	pass


func suspend() -> void:
	pass


func unsuspend() -> void:
	actor.play_animation(animation)


func on_noise(_strength: float) -> void:
	pass


func physics_tick(_delta: float) -> void:
	pass


func go_to(next: StringName) -> void:
	machine.transition_to(next)


func go_to_next_state() -> void:
	if next_states.is_empty():
		push_warning("state %s has no next_states set" % name)
		return
	machine.transition_to(_pick_next_state())


func _pick_next_state() -> StringName:
	if next_state_weights.size() != next_states.size():
		return next_states[actor.random_count(0, next_states.size() - 1)]

	var total := 0.0
	for weight in next_state_weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return next_states[actor.random_count(0, next_states.size() - 1)]

	var roll := actor.random_range(0.0, total)
	for i in next_states.size():
		roll -= maxf(next_state_weights[i], 0.0)
		if roll <= 0.0:
			return next_states[i]
	return next_states[next_states.size() - 1]
