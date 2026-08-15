extends Node3D

const HEAT_LAYER := 8

@export_range(8, 512) var pool_size := 128
@export_range(0.1, 4.0, 0.05) var mark_size := 0.8
@export_range(1.0, 120.0, 0.5) var decay_seconds := 14.0
@export_range(0.0, 0.5, 0.01) var ground_offset := 0.03
@export_range(0.0, 1.0, 0.05) var start_heat := 0.9

var _marks: Array[MeshInstance3D] = []
var _life := PackedFloat32Array()
var _next := 0


func _ready() -> void:
	add_to_group("heat_marks")
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(mark_size, mark_size)
	_life.resize(pool_size)
	for i in pool_size:
		var mark := MeshInstance3D.new()
		mark.mesh = mesh
		mark.layers = HEAT_LAYER
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.material_override = _new_material()
		mark.visible = false
		add_child(mark)
		_marks.append(mark)


func drop(spot: Vector3, heat: float = -1.0) -> void:
	var mark := _marks[_next]
	mark.global_position = Vector3(spot.x, ground_offset, spot.z)
	mark.visible = true
	_life[_next] = decay_seconds * (start_heat if heat < 0.0 else heat)
	_next = (_next + 1) % _marks.size()


func _process(delta: float) -> void:
	for i in _marks.size():
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			_marks[i].visible = false
			continue
		var mat := _marks[i].material_override as StandardMaterial3D
		mat.albedo_color.a = _life[i] / decay_seconds


func live_mark_count() -> int:
	var live := 0
	for i in _life.size():
		if _life[i] > 0.0:
			live += 1
	return live


func _new_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	return mat
