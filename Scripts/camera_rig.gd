extends Node3D

## Slides the game camera ahead of the player, in whatever direction the robot
## is facing, and eases back when it turns. Sits under the (never rotating)
## player body, so a local offset is already a world-space XZ offset.

## How far ahead of the player the camera drifts, in world units.
@export_range(0.0, 8.0) var look_ahead := 2.2
## Higher glides into the new offset faster. Low values feel like a slow float.
@export_range(0.5, 12.0) var glide_speed := 2.5

var _player: Node3D
var _offset := Vector3.ZERO


func _ready() -> void:
	_player = get_parent() as Node3D


func _process(delta: float) -> void:
	var facing: Vector2 = _player.facing
	var target := Vector3(facing.x, 0.0, facing.y) * look_ahead
	# Frame-rate independent exponential ease.
	_offset = _offset.lerp(target, 1.0 - exp(-glide_speed * delta))
	position = _offset
