extends MeshInstance3D

@export var color := Color("ff4d9d")
@export var emission_color := Color(1, 0, 0)
@export_range(0.0, 8.0) var emission_energy := 0.0
@export_range(-4.0, 4.0) var spin_speed := 0.4


func _ready() -> void:
	material_override = _build_material()


func _process(delta: float) -> void:
	pass


func _build_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = emission_energy
	return mat
