class_name SpreadPatternStrategy extends WeaponStrategy

@export_range(0, 90) var spread_angle_degrees: float = 30.0

func _init():
	priority = 10

func apply(context: AttackContext) -> AttackContext:
	context.projectiles_to_spawn.clear()

	var base_direction := (context.target_position - context.muzzle_position).normalized()
	var spread_rad := deg_to_rad(spread_angle_degrees)

	# Add definitions for each projectile to spawn.
	# The WeaponComponent will handle duplicating the data.
	context.projectiles_to_spawn.append({
		"direction": base_direction,
		"attack_data": context.attack_data
	})
	context.projectiles_to_spawn.append({
		"direction": base_direction.rotated(-spread_rad / 2.0),
		"attack_data": context.attack_data
	})
	context.projectiles_to_spawn.append({
		"direction": base_direction.rotated(spread_rad / 2.0),
		"attack_data": context.attack_data
	})

	return context
