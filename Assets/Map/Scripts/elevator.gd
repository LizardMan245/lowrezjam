extends Area3D

@export var needs_all_data := true


func _physics_process(_delta: float) -> void:
	if not Input.is_action_just_pressed("interact") or not has_overlapping_areas():
		return
	var inventory := get_tree().get_first_node_in_group("inventory")
	if needs_all_data and (inventory == null or not inventory.has_all()):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	set_physics_process(false)
	game.win()
