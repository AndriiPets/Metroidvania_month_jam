extends Node # Changed from RefCounted to be a Node attached to enemies
class_name HealthComponent

signal health_changed(old_val: float, new_val: float)
signal died

@export var max_health: float = 100.0
var current_health: float:
	set(new_val):
		var old_val = current_health
		current_health = clamp(new_val, 0, max_health)
		health_changed.emit(old_val, current_health)
		if current_health <= 0:
			died.emit()

func _ready():
	current_health = max_health

## This is the new, type-safe damage function.
func take_damage(attack: AttackData):
	self.current_health -= attack.damage
	print(get_owner().name, " took ", attack.damage, " damage! Health is now ", current_health)
