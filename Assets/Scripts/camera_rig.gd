extends Node3D

@export_range(0.0, 8.0) var look_ahead := 2.2
@export_range(0.5, 12.0) var glide_speed := 2.5

var _player: Node3D
var _offset := Vector3.ZERO


func _ready() -> void:
	_player = get_parent() as Node3D


func _process(delta: float) -> void:
	var facing: Vector2 = _player.facing
	var target := Vector3(facing.x, 0.0, facing.y) * look_ahead
	_offset = _offset.lerp(target, 1.0 - exp(-glide_speed * delta))
	position = _offset
