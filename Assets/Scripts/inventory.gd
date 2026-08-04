extends Node

var held_data: Array

func picked_up_data(data) -> void:
	if data not in held_data:
		held_data.append(data)
		print("picked up ", data)
	else:
		print("already had ", data)
