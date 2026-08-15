extends TextureRect

@export var levels: int
@export var level_val: int
var curr_level = 0
var is_selected = false

@export var base_sprites: Array
@export var sel_sprites: Array

func select() -> void:
	is_selected = true
	$".".texture = sel_sprites[curr_level]


func deselect() -> void:
	is_selected = false
	$".".texture = base_sprites[curr_level]


func edit_ram_usage() -> int:
	var ram_change: int = 0
	
	if Input.is_action_just_pressed("look_right") and curr_level < levels:
		curr_level += 1
		ram_change += level_val
		$".".texture = sel_sprites[curr_level]
	
	if Input.is_action_just_pressed("look_left") and curr_level > 0:
		curr_level -= 1
		ram_change -= level_val
		$".".texture = sel_sprites[curr_level]
	
	return ram_change

func ram_used() -> int:
	return curr_level * level_val
