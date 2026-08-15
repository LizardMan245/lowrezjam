extends Node

@export_range(0.2, 4.0, 0.1) var catch_distance := 1.1

var _hunter: Node3D
var _player: Node3D


func _ready() -> void:
	_hunter = get_parent() as Node3D
	if _hunter == null:
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if _hunter.global_position.distance_to(_player.global_position) > catch_distance:
		return
	if _player.get("godmode"):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	set_physics_process(false)
	game.lose()
