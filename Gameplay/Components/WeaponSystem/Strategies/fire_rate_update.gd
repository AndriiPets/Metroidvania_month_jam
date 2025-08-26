class_name FireRateUpgradeStrategy extends WeaponStrategy

@export_range(0, 1.0) var reduction_amount: float = 0.3

func _init():
	# This strategy doesn't modify the attack context, it modifies the component itself.
	# We give it a high priority so it runs late, though order doesn't matter much for this one.
	priority = 200

func apply(context: AttackContext) -> AttackContext:
	# This strategy simply adds its reduction amount to the context.
	# The WeaponComponent is responsible for the final calculation.
	context.fire_rate_reduction_percentage += reduction_amount
	return context