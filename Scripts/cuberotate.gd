extends RigidBody3D

@export_range(0.0, 8.0) var emission_energy := 0.0
@export_range(-4.0, 4.0) var spin_speed := 0.4

var _origin := Vector3.ZERO
var _time := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_origin = position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_time += delta
	rotation.y = _time * spin_speed * TAU
