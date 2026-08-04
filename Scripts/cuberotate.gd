extends RigidBody3D

@export_range(-4.0, 4.0) var spin_speed := 0.4

var _origin := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_origin = position


func _process(delta: float) -> void:
	_time += delta
	rotation.y = _time * spin_speed * TAU
