extends CharacterBody3D


const SPEED = 5.0

@export_range(1.0, 30.0) var turn_speed := 7.0
@export_range(5.0, 180.0) var vision_angle_degrees := 45.0
@export_range(1.0, 40.0) var view_distance := 7.0
@export_range(0.0, 4.0) var eye_height := 1.55

var facing := Vector2(0.0, 1.0)

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_apply_facing()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		_turn_toward(Vector2(direction.x, direction.z), delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _turn_toward(dir: Vector2, delta: float) -> void:
	var current := atan2(facing.x, facing.y)
	var target := atan2(dir.x, dir.y)
	var angle := lerp_angle(current, target, 1.0 - exp(-turn_speed * delta))
	facing = Vector2(sin(angle), cos(angle))
	_apply_facing()


func _apply_facing() -> void:
	_visual.rotation.y = atan2(-facing.x, -facing.y)


func get_eye_position() -> Vector3:
	return global_position + Vector3(0.0, eye_height, 0.0)


func get_noise_level() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / SPEED, 0.0, 1.0)
