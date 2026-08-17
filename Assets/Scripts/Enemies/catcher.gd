extends Node

@export_range(0.0, 3.0, 0.05) var extra_reach := 0.35

var _hunter: Node3D
var _player: Node3D
var _reach := 0.0


func _ready() -> void:
	_hunter = get_parent() as Node3D
	if _hunter == null:
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player != null:
			_reach = BodySize.of(_hunter) + BodySize.of(_player) + extra_reach
		return
	if flat_distance(_hunter.global_position, _player.global_position) > _reach:
		return
	if _player.get("godmode"):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	set_physics_process(false)
	game.lose()


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
