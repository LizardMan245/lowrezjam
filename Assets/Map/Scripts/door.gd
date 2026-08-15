extends Node3D

var opening_dist: float = 2.8
var base_dist: float = 1
@export var opening_speed: int = 10

@onready var left_side = $LeftSide as RigidBody3D
@onready var right_side = $RightSide as RigidBody3D

enum states {closed, opening, opened, closing}
@export var curr_state := states.closed


func open_door(delta) -> void:
	if right_side.position.x < opening_dist:
		right_side.position.x += opening_speed * delta
		left_side.position.x = - right_side.position.x
	else:
		right_side.position.x = opening_dist
		left_side.position.x = - right_side.position.x
		curr_state = states.opened


func close_door(delta) -> void:
	if right_side.position.x > base_dist:
		right_side.position.x -= opening_dist * delta
		left_side.position.x = - right_side.position.x
	else:
		right_side.position.x = base_dist
		left_side.position.x = - right_side.position.x
		curr_state = states.closed


func _on_area_3d_body_entered(_body: Node3D) -> void:
	curr_state = states.opening


func _on_area_3d_body_exited(_body: Node3D) -> void:
	if not $Area3D.has_overlapping_bodies():
		curr_state = states.closing


func _process(delta: float) -> void:
	match curr_state:
		states.opening:
			open_door(delta)
		states.closing:
			close_door(delta)
