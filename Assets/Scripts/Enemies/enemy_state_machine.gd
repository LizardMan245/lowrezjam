extends Node

const EnemyState = preload("res://Assets/Scripts/Enemies/enemy_state.gd")

const MAX_CHAINED_TRANSITIONS := 8

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: StringName = &""

var actor
var current: EnemyState

var _states := {}
var _transition_depth := 0
var _suspended: EnemyState
var _previous_state_name: StringName = &""


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
	_drop_suspended()
	var previous := get_state_name()
	if current != null:
		current.exit()
	_previous_state_name = previous
	current = _states[next]
	current.apply_senses()
	current.enter()
	state_changed.emit(previous, next)
	_transition_depth -= 1


func interrupt_with(next: StringName) -> void:
	if not _states.has(next) or current == null:
		return
	if _transition_depth >= MAX_CHAINED_TRANSITIONS:
		push_warning("too many state changes at once while entering %s" % next)
		return

	_transition_depth += 1
	_drop_suspended()
	var previous := get_state_name()
	_suspended = current
	_suspended.suspend()
	_previous_state_name = previous
	current = _states[next]
	current.apply_senses()
	current.enter()
	state_changed.emit(previous, next)
	_transition_depth -= 1


func resume_previous() -> void:
	if _suspended == null:
		transition_to(initial_state if _states.has(initial_state) else get_state_name())
		return

	var previous := get_state_name()
	var back := _suspended
	_suspended = null
	current.exit()
	_previous_state_name = previous
	current = back
	current.apply_senses()
	current.unsuspend()
	state_changed.emit(previous, StringName(back.name))


func _drop_suspended() -> void:
	if _suspended == null:
		return
	var dropped := _suspended
	_suspended = null
	dropped.exit()


func physics_tick(delta: float) -> void:
	if current == null:
		return
	if current.interrupt_on_detection and actor.has_detected_player():
		transition_to(current.detection_state)
	elif actor.has_noise_cue():
		_route_noise_cue()
	current.physics_tick(delta)


func _route_noise_cue() -> void:
	if current.noise_response == EnemyState.NoiseResponse.IGNORE:
		actor.discard_noise_cue()
		return

	var strength: float = actor.take_noise_cue()
	if current.noise_response == EnemyState.NoiseResponse.REDIRECT:
		current.on_noise(strength)
		return

	if actor.noise_is_loud(strength):
		if _states.has(current.investigate_state):
			transition_to(current.investigate_state)
		return
	if _states.has(current.glance_state):
		interrupt_with(current.glance_state)


func get_state_name() -> StringName:
	return StringName(current.name) if current != null else &""


func get_previous_state_name() -> StringName:
	return _previous_state_name
