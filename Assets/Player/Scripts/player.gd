extends CharacterBody3D

var SPEED = 0.0
@export_range(0.0, 30.0) var turn_speed := 0.0
@export_range(5.0, 180.0) var vision_angle_degrees := 45.0
@export_range(0.0, 40.0) var view_distance := 0.0
@export_range(0.0, 4.0) var eye_height := 2.0

@export var ram_size: float = 3
@export var godmode := false
@export_range(0.5, 20.0, 0.5) var loud_speed := 8.0
@export_range(0.0, 4.0, 0.05) var burst_fade := 1.6

var facing := Vector2(0.0, -1.0)
var _noise_burst := 0.0


@onready var _visual: Node3D = $Visual
var ui: Control

@onready var _animated_sprite = $Visual/AnimatedSprite3D


func _ready() -> void:
	_apply_facing()
	ui = get_tree().get_first_node_in_group("ui") as Control


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var look_dir := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if look_dir and not in_menu():
		_turn_toward(look_dir, delta)
	
	if input_dir:
		velocity.x = input_dir.x * SPEED
		velocity.z = input_dir.y * SPEED
		if not look_dir:
			_turn_toward(input_dir, delta)
		

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_noise_burst = maxf(_noise_burst - burst_fade * delta, 0.0)
	
func _process(_delta: float) -> void:
	if view_distance == 0.0:
		$Visual/AnimatedSprite3D.visible = false
	else:
		$Visual/AnimatedSprite3D.visible = true


func get_noise_level() -> float:
	return maxf(_step_noise(), _noise_burst)


func make_noise(amount: float) -> void:
	_noise_burst = maxf(_noise_burst, clampf(amount, 0.0, 1.0))


func _step_noise() -> float:
	if loud_speed <= 0.0:
		return 0.0
	return clampf(Vector2(velocity.x, velocity.z).length() / loud_speed, 0.0, 1.0)


func in_menu() -> bool:
	return ui != null and ui.in_menu


func _turn_toward(dir: Vector2, delta: float) -> void:
	var current := atan2(facing.x, facing.y)
	var target := atan2(dir.x, dir.y)
	var angle := lerp_angle(current, target, 1.0 - exp(-turn_speed * delta))
	facing = Vector2(sin(angle), cos(angle))
	_apply_facing()


func _apply_facing() -> void:
	_visual.rotation.y = atan2(-facing.x, -facing.y)


func get_ram_radius() -> float:
	var shape := $RamArea/CollisionShape3D.shape as CylinderShape3D
	return shape.radius if shape != null else 0.0


func get_eye_position() -> Vector3:
	return global_position + Vector3(0.0, eye_height, 0.0)


func _on_ui_resize_ram_radius(ram: Variant) -> void:
	var ram_area: CylinderShape3D = CylinderShape3D.new()
	ram_area.height = 2
	ram_area.radius = ram * ram_size
	$RamArea/CollisionShape3D.shape = ram_area
	_show_ram_radius(ram_area.radius)


func _show_ram_radius(radius: float) -> void:
	var disc := get_node_or_null("RamArea/RamDebug") as Node3D
	if disc == null:
		return
	var wide := maxf(radius, 0.01)
	disc.scale = Vector3(wide, 1.0, wide)
	disc.visible = radius > 0.01
