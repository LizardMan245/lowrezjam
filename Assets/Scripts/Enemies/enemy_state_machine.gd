extends Node

const EnemyState = preload("res://Assets/Scripts/Enemies/enemy_state.gd")

const MAX_CHAINED_TRANSITIONS := 8

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: StringName = &""

var actor
var current: EnemyState

var _states := {}
var _transition_depth := 0


func setup(owner_actor) -> void:
	actor = owner_actor
	for child in get_children():
		var state := child as EnemyState
		if state == null:
			push_warning("Child \"%s\" of the state machine is not an enemy state." % child.name)
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
		push_warning("Enemy state machine has no state named \"%s\"." % next)
		return
	if _transition_depth >= MAX_CHAINED_TRANSITIONS:
		push_warning("Enemy state machine hit a transition loop while entering \"%s\"." % next)
		return

	_transition_depth += 1
	var previous := get_state_name()
	if current != null:
		current.exit()
	current = _states[next]
	current.enter()
	state_changed.emit(previous, next)
	_transition_depth -= 1


func physics_tick(delta: float) -> void:
	if current == null:
		return
	if current.interrupt_on_detection and actor.has_detected_player():
		transition_to(current.detection_state)
	current.physics_tick(delta)


func get_state_name() -> StringName:
	return StringName(current.name) if current != null else &""
