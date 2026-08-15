extends Control

@export_range(0.0, 60.0, 0.5) var radius := 0.0
@export_range(0.2, 10.0, 0.1) var ping_interval := 2.5
@export_range(0.1, 4.0, 0.1) var blip_seconds := 0.9
@export var blip_color := Color(0.35, 1.0, 0.75, 1.0)
@export_range(1, 8) var blip_size := 2
@export_range(1, 32) var pool_size := 8

var _blips: Array[ColorRect] = []
var _life := PackedFloat32Array()
var _timer := 0.0
var _player: Node3D
var _camera: Camera3D
var _ring: Node3D
var _waiting: Array[Node3D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_life.resize(pool_size)
	for i in pool_size:
		var blip := ColorRect.new()
		blip.color = blip_color
		blip.size = Vector2(blip_size, blip_size)
		blip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blip.visible = false
		add_child(blip)
		_blips.append(blip)


func _process(delta: float) -> void:
	for i in _blips.size():
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			_blips[i].visible = false
		else:
			_blips[i].modulate.a = _life[i] / blip_seconds

	if radius <= 0.0:
		_waiting.clear()
		return

	_sweep()

	_timer -= delta
	if _timer <= 0.0:
		_timer = ping_interval
		ping()


func ping() -> int:
	if not _find_helpers():
		return 0
	_waiting.clear()
	for mob in get_tree().get_nodes_in_group("enemy"):
		if _gap_to(mob) <= radius:
			_waiting.append(mob)
	if _ring != null:
		_ring.pulse(radius)
	return _waiting.size()


func _sweep() -> void:
	if _waiting.is_empty() or not _find_helpers():
		return
	var reached: float = _ring.radius if _ring != null else radius
	for mob in _waiting.duplicate():
		if _gap_to(mob) > reached:
			continue
		_waiting.erase(mob)
		_mark(mob)


func _mark(mob: Node3D) -> void:
	var slot := _free_blip()
	if slot < 0:
		return
	var blip := _blips[slot]
	blip.position = _on_screen(_camera.unproject_position(mob.global_position + Vector3(0.0, 1.0, 0.0))) - blip.size * 0.5
	blip.visible = true
	blip.modulate.a = 1.0
	_life[slot] = blip_seconds


func _free_blip() -> int:
	var oldest := 0
	for i in _life.size():
		if _life[i] <= 0.0:
			return i
		if _life[i] < _life[oldest]:
			oldest = i
	return oldest


func _gap_to(mob: Node3D) -> float:
	var here: Vector3 = mob.global_position
	return Vector2(here.x - _player.global_position.x, here.z - _player.global_position.z).length()


func _find_helpers() -> bool:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _camera == null:
		_camera = get_tree().get_first_node_in_group("game_camera") as Camera3D
	if _ring == null:
		_ring = get_tree().get_first_node_in_group("echo_ring") as Node3D
	return _player != null and _camera != null


func _on_screen(at: Vector2) -> Vector2:
	var edge := float(blip_size)
	return Vector2(clampf(at.x, edge, size.x - edge), clampf(at.y, edge, size.y - edge))


func live_blip_count() -> int:
	var live := 0
	for i in _life.size():
		if _life[i] > 0.0:
			live += 1
	return live
