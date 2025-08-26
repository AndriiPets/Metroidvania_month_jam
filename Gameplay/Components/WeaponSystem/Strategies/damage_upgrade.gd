class_name DamageUpgradeStrategy extends WeaponStrategy

## How much damage to add to the base damage.
@export var damage_increase: float = 5.0

func _init():
	# A stat modifier.
	priority = 100

func apply(context: AttackContext) -> AttackContext:
	context.attack_data.damage += damage_increase
	return context
