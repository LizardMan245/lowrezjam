extends Node3D

@export var destination: NodePath
@export var cooldown_sec: float = 60

var dest_coords: Vector3
var difference: Vector3

@onready var teleporter = $Areas/Teleporter
@onready var tp_turn_off1 = $Areas/TpTurnOff
@onready var tp_turn_off2 = $Areas/TpTurnOff2


func _ready() -> void:
	dest_coords = get_node(destination).global_position
	var start_coords = $Areas/Teleporter/CollisionShape3D.global_position
	difference = dest_coords - start_coords
	teleporter.monitoring = false
	tp_turn_off1.monitoring = false
	tp_turn_off2.monitoring = false
	$ClosingWalls.position.y = -6


func _on_teleporter_body_entered(_body: Node3D) -> void:
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	player.position += Vector3(difference.x, 0.0, difference.z)
	teleporter.set_deferred("monitoring", false)
	tp_turn_off1.monitoring = false
	tp_turn_off2.monitoring = false


func _on_tp_turn_on_body_entered(_body: Node3D) -> void:
	teleporter.monitoring = true
	tp_turn_off1.monitoring = true
	tp_turn_off2.monitoring = true
	$ClosingWalls.position.y = -6
	$Timer.stop()


func _on_tp_turn_off_body_entered(_body: Node3D) -> void:
	teleporter.monitoring = false
	tp_turn_off1.set_deferred("monitoring", false)
	tp_turn_off2.set_deferred("monitoring", false)


func _on_closer_body_exited(_body: Node3D) -> void:
	$AudioStreamPlayer3D.play()
	$AudioStreamPlayer3D2.play()
	$ClosingWalls.position.y = 0
	$Timer.start(cooldown_sec)


func _on_timer_timeout() -> void:
	$ClosingWalls.position.y = -6
	#print("timer over")
