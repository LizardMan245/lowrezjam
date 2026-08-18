extends Control

@export var curr_slide := 0
@export var slides: Array
@export var slide_shower: NodePath
@export var select_sfx: AudioStream


func next_slide() -> void:
	var slide_shower_node = get_node(slide_shower) as TextureRect
	if curr_slide + 1 < slides.size():
		curr_slide += 1
	else:
		curr_slide = 0
	$Sfx.stream = select_sfx
	$Sfx.play()
	slide_shower_node.texture = slides[curr_slide]

func game_start() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		$Animators/FadeIn.play("fade_out")
	if Input.is_action_just_pressed("menu"):
		next_slide()
