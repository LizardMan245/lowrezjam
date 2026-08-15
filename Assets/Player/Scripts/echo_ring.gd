extends Node3D

const PLAYER_LAYER := 2

@export_range(0.1, 4.0, 0.05) var grow_seconds := 1.1
@export_range(0.02, 1.0, 0.01) var thickness := 0.12
@export var ring_color := Color(0.35, 1.0, 0.75, 0.9)

var radius := 0.0

var _target := 0.0
var _timer := 0.0
var _ring: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group("echo_ring")
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.0 - thickness
	mesh.outer_radius = 1.0
	mesh.rings = 16
	mesh.ring_segments = 6

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = ring_color

	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_ring.layers = PLAYER_LAYER
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.material_override = _material
	_ring.visible = false
	add_child(_ring)


func pulse(reach: float) -> void:
	if reach <= 0.0:
		return
	_target = reach
	_timer = grow_seconds
	radius = 0.0
	_ring.visible = true


func running() -> bool:
	return _timer > 0.0


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer = maxf(_timer - delta, 0.0)
	var progress := 1.0 - _timer / grow_seconds
	radius = _target * progress
	_ring.scale = Vector3(maxf(radius, 0.01), 1.0, maxf(radius, 0.01))
	_material.albedo_color.a = ring_color.a * (1.0 - progress)
	if _timer <= 0.0:
		_ring.visible = false
		radius = 0.0
