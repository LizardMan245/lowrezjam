extends Node3D

@export var aggro_states: Array[StringName] = [&"Chase"]


func _ready() -> void:
	var actor := get_parent().get_parent()
	if actor == null or not actor.has_signal("state_changed"):
		push_warning("aggro needs to sit under an enemy")
		return
	actor.state_changed.connect(_on_state_changed)
	
func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current in aggro_states:
		visible = true
	else:
		visible = false
