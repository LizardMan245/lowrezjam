extends Control

var slides
var curr_slide: int = 0


func _ready() -> void:
	slides = $Slides.get_children() as Array[Control]
	slides[curr_slide].visible = true



func next_slide() -> void:
	if curr_slide + 1 < slides.size():
		slides[curr_slide].visible = false
		curr_slide += 1
		slides[curr_slide].visible = true
	else:
		get_tree().change_scene_to_file("res://Scenes/Screens/Menu.tscn")
	
