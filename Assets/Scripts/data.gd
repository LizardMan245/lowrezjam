extends Area2D

var data: String = "first_door"

func _on_body_entered(body: Node2D) -> void:
	var inventory = $"../Inventory"
	inventory.picked_up_data(data)
