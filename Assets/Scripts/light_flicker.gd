extends Light3D

@export var base_energy := 0.25
@export_range(0.0, 1.0) var flicker_depth := 0.35
@export_range(0.1, 20.0) var flicker_speed := 6.0
@export_range(0.0, 0.05, 0.001) var dropout_chance := 0.004

var _time := 0.0
var _dropout := 0.0


func _process(delta: float) -> void:
	_time += delta * flicker_speed

	if _dropout > 0.0:
		_dropout -= delta
	elif randf() < dropout_chance:
		_dropout = randf_range(0.04, 0.14)

	var wobble := sin(_time) * 0.6 + sin(_time * 2.37 + 1.1) * 0.3 + sin(_time * 5.11 + 2.7) * 0.1
	var energy := base_energy * (1.0 + wobble * flicker_depth)
	if _dropout > 0.0:
		energy *= 0.15

	light_energy = maxf(energy, 0.0)
