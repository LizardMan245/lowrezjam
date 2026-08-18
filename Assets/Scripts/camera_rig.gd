extends Node3D

@export_range(0.0, 8.0) var look_ahead := 2.2
@export_range(0.5, 12.0) var glide_speed := 2.5
@export var look_ahead_multiplier: float = 3

var _player: CharacterBody3D
var ui: Control
var _offset := Vector3.ZERO

var facing: Vector2
var input_dir: Vector2
var last_input_dir: Vector2 = Vector2.UP
var look_dir: Vector2

func _ready() -> void:
	_player = get_parent() as Node3D
	ui = get_tree().get_first_node_in_group("ui") as Control


func _process(delta: float) -> void:
	facing = _player.facing
	var target := Vector3(facing.x, 0.0, facing.y) * look_ahead
	
	if not ui.in_menu:
		look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	else:
		look_dir = Vector2.ZERO
	input_dir = Input.get_vector("left", "right", "up", "down")
	
	if input_dir:
		last_input_dir = input_dir
	
	if look_dir == last_input_dir:
		target *= look_ahead_multiplier
	
	_offset = _offset.lerp(target, 1.0 - exp(-glide_speed * delta))
	position = _offset
