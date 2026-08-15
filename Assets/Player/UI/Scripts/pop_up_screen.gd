extends Area3D

@export var slides: Array
@export var popup_time: float = 0.2

var popup_on: bool = false
var curr_slide: int = 0

var ui: Control

func _ready() -> void:
	ui = get_tree().get_first_node_in_group("ui") as Control


func next_slide() -> void:
	if curr_slide < slides.size():
		ui.popup_doer("next", slides[curr_slide], popup_time)
		print(curr_slide)
		curr_slide += 1
	else:
		ui.popup_doer("down", slides[-1], popup_time)
		popup_on = false
		curr_slide = 0


func _physics_process(_delta: float) -> void:
	var interacted := Input.is_action_just_pressed("interact") and has_overlapping_areas()
	if interacted:
		if not popup_on:
			ui.popup_doer("up", slides[0], popup_time)
			popup_on = true
			curr_slide = 1
		else:
			next_slide()


func _on_area_exited(_area: Area3D) -> void:
	if popup_on:
		ui.popup_doer("down", slides[-1], popup_time)
		popup_on = false
		curr_slide = 0
		
