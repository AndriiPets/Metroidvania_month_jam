extends CharacterBody2D
class_name Bullet

@onready var sprite := %Sprite

var attack_data: AttackData # The bullet now holds its own attack data.

func launch(spawn_pos: Vector2, direction: Vector2, data: AttackData) -> void:
	position = spawn_pos
	attack_data = data
	velocity = direction * attack_data.speed
	look_at(position + direction)

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		# You can check for a group or a specific class here.
		# A better way is to check if it has a HealthComponent.
		if collider.has_method("take_damage"):
			collider.take_damage(attack_data)
		
		queue_free()