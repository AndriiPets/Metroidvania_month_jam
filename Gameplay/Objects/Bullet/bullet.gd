extends CharacterBody2D
class_name Bullet

const VFX_SPAWN_OFFSET: float = 10.0

@onready var sprite := %Sprite
var attack_data: AttackData
var dir: Vector2 = Vector2.ZERO

func launch(spawn_pos: Vector2, direction: Vector2, data: AttackData) -> void:
	position = spawn_pos
	attack_data = data
	# We still need the velocity for the move_and_collide check against walls.
	velocity = direction * attack_data.speed
	dir = velocity
	look_at(position + direction)

func _physics_process(delta: float) -> void:
	# 1. Calculate the movement for this frame
	var movement_vector = velocity * delta

	# 2. Get the direct physics space state to perform a cast
	var space_state = get_world_2d().direct_space_state

	# 3. Define the query parameters for the raycast
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + movement_vector)
	# Important: Make sure the query's collision mask matches the bullet's mask
	query.collision_mask = self.get_collision_mask()

	# --- FIX: Enable collision with Area2D ---
	query.collide_with_areas = true

	# 4. Execute the raycast
	var result = space_state.intersect_ray(query)

	# 5. Process the result
	if result:
		# A hit was detected!
		var collider = result.collider

		# Check if the object we hit has a HurtboxComponent
		if collider is HurtboxComponent:
			var hurtbox: HurtboxComponent = collider
			hurtbox.recieve_attack_data(attack_data, velocity.normalized())
			print("Hit ", hurtbox.get_owner().name, " via raycast!")

			## ON HIT VFX
			var impact_normal = result.normal
			var rotation_from_normal = rad_to_deg(impact_normal.angle()) + 90
			# Calculate the new spawn position by pushing it against the normal
			var vfx_spawn_pos = result.position - impact_normal * VFX_SPAWN_OFFSET

			VFXManager.spawn_vfx("land", vfx_spawn_pos, {"rotation_degrees": rotation_from_normal})

		# We hit something, so destroy the bullet
		#print("Bullet: collided with a wall via raycast")
		queue_free()
		return # Stop further processing

	# If no raycast hit, move the bullet normally to check for walls/obstacles.
	var collision := move_and_collide(movement_vector)
	if collision:
		# This handles colliding with static geometry (like walls).
		#print("Bullet: collided with a wall via collider")
		# Get the normal from the collision result.
		var impact_normal = collision.get_normal()
		var rotation_from_normal = rad_to_deg(impact_normal.angle()) + 90
		var vfx_spawn_pos = position - impact_normal * VFX_SPAWN_OFFSET

		# Spawn the VFX using the normal's angle for rotation.
		VFXManager.spawn_vfx("takeoff", vfx_spawn_pos, {"rotation_degrees": rotation_from_normal})
		queue_free()
