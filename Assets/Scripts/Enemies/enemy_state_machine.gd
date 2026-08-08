extends Node

const EnemyState = preload("res://Assets/Scripts/Enemies/enemy_state.gd")

const MAX_CHAINED_TRANSITIONS := 8

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: StringName = &""

var actor
var current: EnemyState

var _states := {}
var _transition_depth := 0
var _resume_state: StringName = &""


func setup(owner_actor) -> void:
	actor = owner_actor
	for child in get_children():
		var state := child as EnemyState
		if state == null:
			push_warning("child %s is not a state, skipped" % child.name)
			continue
		_states[StringName(child.name)] = state
		state.setup(actor, self)


func start() -> void:
	var first := initial_state
	if not _states.has(first):
		first = StringName(get_child(0).name) if get_child_count() > 0 else &""
	if first != &"":
		transition_to(first)


func transition_to(next: StringName) -> void:
	if not _states.has(next):
		push_warning("there is no state called %s" % next)
		return
	if _transition_depth >= MAX_CHAINED_TRANSITIONS:
		push_warning("too many state changes at once while entering %s" % next)
		return

	_transition_depth += 1
	_resume_state = &""
	var previous := get_state_name()
	if current != null:
		current.exit()
	current = _states[next]
	current.enter()
	state_changed.emit(previous, next)
	_transition_depth -= 1


func interrupt_with(next: StringName) -> void:
	var interrupted := get_state_name()
	transition_to(next)
	if get_state_name() == next:
		_resume_state = interrupted


func resume_previous() -> void:
	var back := _resume_state
	_resume_state = &""
	if back != &"" and _states.has(back):
		transition_to(back)
		return
	if _states.has(initial_state):
		transition_to(initial_state)


func physics_tick(delta: float) -> void:
	if current == null:
		return
	if current.interrupt_on_detection and actor.has_detected_player():
		transition_to(current.detection_state)
	elif current.interrupt_on_noise and get_state_name() != current.noise_state and actor.wants_to_glance():
		actor.use_glance()
		if _states.has(current.noise_state):
			interrupt_with(current.noise_state)
	current.physics_tick(delta)


func get_state_name() -> StringName:
	return StringName(current.name) if current != null else &""
