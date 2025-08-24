extends RefCounted
class_name HeathComponent

signal health_changed(old: int, new: int)

var value: int:
	set(new_val):
		health_changed.emit(value, new_val)
		value = new_val

func _init(hp: int = 100) -> void:
	value = hp

func damage(amount: int) -> void:
	value -= amount

func heal(amount: int) -> void:
	value += amount
