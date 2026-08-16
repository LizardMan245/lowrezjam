extends MeshInstance3D

@export var base_energy := 0.25
@export_range(0.0, 3.0) var flicker_depth := 0.35
@export_range(0.1, 20.0) var flicker_speed := 6.0

var _time := 0.0

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	var wobble := cos(_time) * 0.6 + sin(_time * 2.37 + 1.1) * 0.3 + cos(_time * 5.11 + 2.7) * 0.1
	var energy := base_energy * (1.0 + wobble * flicker_depth)
	get_surface_override_material(0).emission_energy_multiplier = energy
