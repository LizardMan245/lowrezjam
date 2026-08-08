extends Node

const EnemyActor = preload("res://Assets/Scripts/Enemies/enemy_actor.gd")

@export var animation: StringName = &""
@export var interrupt_on_detection := true
@export var detection_state: StringName = &"Alert"
@export var interrupt_on_noise := true
@export var noise_state: StringName = &"Glance"
@export var next_states: Array[StringName] = []
@export var next_state_weights: Array[float] = []

var actor: EnemyActor
var machine


func setup(owner_actor: EnemyActor, owner_machine) -> void:
	actor = owner_actor
	machine = owner_machine


func enter() -> void:
	actor.play_animation(animation)


func exit() -> void:
	pass


func physics_tick(_delta: float) -> void:
	pass


func go_to(next: StringName) -> void:
	machine.transition_to(next)


func go_to_next_state() -> void:
	if next_states.is_empty():
		push_warning("State %s has no next_states set." % name)
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
