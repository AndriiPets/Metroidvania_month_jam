extends CharacterBody2D
class_name Bullet

var dir: Vector2 = Vector2.ZERO
var speed: float = 100.0
var pos: Vector2 = Vector2.ZERO

func launch(bullet_pos: Vector2, bullet_direction: Vector2, bullet_speed: float) -> void:
	position = bullet_pos
	dir = bullet_direction
	speed = bullet_speed
	velocity = dir * speed

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(velocity * delta)
	if collision:
		queue_free()
