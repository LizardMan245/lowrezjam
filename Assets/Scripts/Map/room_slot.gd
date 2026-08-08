extends Node3D

@export var tiles := Vector2i(3, 3)


func get_door_markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	var holder := get_node_or_null("Doors")
	if holder == null:
		return markers
	for child in holder.get_children():
		var marker := child as Marker3D
		if marker != null:
			markers.append(marker)
	return markers
