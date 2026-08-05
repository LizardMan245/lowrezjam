extends Node

var held_data: Dictionary
var RAM: int

func data_drop(data) -> void:
	RAM -= held_data[data]
	held_data.erase(data)
	$"../CanvasLayer/UI".ui_update(held_data, RAM)



func data_pickup(data: String, size: int) -> void:
	if data not in held_data.keys():
		held_data[data] = size
		RAM += size
		$"../CanvasLayer/UI".ui_update(held_data, RAM)
		print("picked up ", data)
	else:
		print("already had ", data)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("drop_data") and held_data.size() > 0:
		var first_data = held_data.keys()[0]
		data_drop(first_data)
