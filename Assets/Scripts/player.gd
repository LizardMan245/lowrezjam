extends CharacterBody2D

var move_speed: int = 200

var direction: Vector2 = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")
	
	velocity = direction * move_speed
	move_and_slide()
