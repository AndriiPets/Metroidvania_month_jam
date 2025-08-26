class_name WeaponStrategy extends Resource
## The priority determines the order of execution. Lower numbers run first.
## 0-99: Base patterns (single shot, shotgun, etc.)
## 100-199: Stat modifications (damage, speed, etc.)
## 200-299: Behavior changes (piercing, homing, etc.)
@export var priority: int = 100

## This is the core method every strategy must implement.
## It takes the attack's data (the context), modifies it, and returns it.
func apply(context: AttackContext) -> AttackContext:
	# Base function does nothing. It must be overridden by child classes.
	return context
