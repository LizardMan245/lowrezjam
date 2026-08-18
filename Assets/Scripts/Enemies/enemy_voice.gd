extends Node3D

const LoopingSound = preload("res://Assets/Scripts/looping_sound.gd")

@export var rush_states: Array[StringName] = [&"Chase", &"CatchUp", &"Search"]
@export var calm_states: Array[StringName] = [&"RoamWalk", &"RoamIdle", &"Glance", &"Investigate", &"Scan"]

var _rush: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D


func _ready() -> void:
	_rush = get_node_or_null("Rush") as AudioStreamPlayer3D
	_breath = get_node_or_null("Breath") as AudioStreamPlayer3D
	_prepare(_rush)
	_prepare(_breath)

	var actor := get_parent()
	if actor == null or not actor.has_signal("state_changed"):
		push_warning("enemyvoice needs to sit under an enemy")
		return
	actor.state_changed.connect(_on_state_changed)


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	_switch(_rush, current in rush_states)
	_switch(_breath, current in calm_states)


func _switch(player: AudioStreamPlayer3D, wanted: bool) -> void:
	if player == null or player.stream == null:
		return
	if wanted and not player.playing:
		player.play()
	elif not wanted and player.playing:
		player.stop()


func _prepare(player: AudioStreamPlayer3D) -> void:
	if player == null or player.stream == null:
		return
	if not LoopingSound.loop_the_stream(player.stream):
		player.finished.connect(player.play)
