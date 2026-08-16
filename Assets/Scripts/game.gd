extends Node3D

@export_file("*.tscn") var victory_scene := "res://Scenes/Screens/Victory.tscn"
@export_file("*.tscn") var lose_scene := "res://Scenes/Screens/Lose.tscn"
@export var ambience: AudioStream

var finished := false


func _ready() -> void:
	add_to_group("game")
	if ambience != null:
		var speaker := AudioStreamPlayer.new()
		speaker.stream = ambience
		add_child(speaker)
		speaker.play()


func win() -> void:
	_leave(victory_scene)


func lose() -> void:
	_leave(lose_scene)


func _leave(where: String) -> void:
	if finished:
		return
	finished = true
	get_tree().change_scene_to_file(where)
