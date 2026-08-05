extends Area2D

@export var data: String = ""
@export var size: int = 0

func _on_body_entered(_body: Node2D) -> void:
	$"../Inventory".data_pickup(data, size)
