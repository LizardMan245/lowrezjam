extends Control

@export_file("*.tscn") var play_scene := "res://Scenes/Main.tscn"
@export_file("*.tscn") var menu_scene := "res://Scenes/Screens/Menu.tscn"
@export var starts_game := false
@export var music: AudioStream
@export_range(0.0, 4.0, 0.05) var input_delay := 0.6

var _wait := 0.0


func _ready() -> void:
	_wait = input_delay
	if music != null:
		var speaker := AudioStreamPlayer.new()
		speaker.stream = music
		add_child(speaker)
		speaker.play()


func _process(delta: float) -> void:
	_wait = maxf(_wait - delta, 0.0)
	if _wait > 0.0:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("menu"):
		get_tree().change_scene_to_file(play_scene if starts_game else menu_scene)
