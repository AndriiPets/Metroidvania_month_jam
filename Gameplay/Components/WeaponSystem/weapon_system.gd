# Gameplay/Components/WeaponSystem/weapon_system.gd
class_name WeaponComponent extends Node

signal recoil_shot(direction: Vector2)

## The default attack stats for this weapon. Create a .tres file from AttackData and assign it here.
@export var base_attack_data: AttackData

@export var strategies: Array[WeaponStrategy] = []
@export var base_fire_rate: float = 1.0
@export var min_fire_rate: float = 0.1

@onready var fire_rate_timer: Timer = $FireRateTimer

var _can_fire: bool = true

func _ready() -> void:
	_update_strategies()

	fire_rate_timer.one_shot = true
	fire_rate_timer.timeout.connect(func(): _can_fire = true)

## Adds a new strategy resource at runtime and updates the weapon's stats.
func add_strategy(new_strategy: WeaponStrategy) -> void:
	print("Adding new strategy: ", new_strategy.resource_path)
	strategies.append(new_strategy)
	_update_strategies()

## This private function now contains all the logic for updating the weapon's state.
func _update_strategies() -> void:
	strategies.sort_custom(func(a, b): return a.priority < b.priority)
	_calculate_and_set_fire_rate()

func _calculate_and_set_fire_rate() -> void:
	var context := AttackContext.new()
	# Apply only the strategies that affect the fire rate.
	for strategy in strategies:
		if strategy is FireRateUpgradeStrategy:
			context = strategy.apply(context)

	var total_reduction = context.fire_rate_reduction_percentage
	var modified_rate = base_fire_rate * (1.0 - total_reduction)
	var final_rate = max(modified_rate, min_fire_rate)

	fire_rate_timer.wait_time = final_rate
	print("WeaponComponent updated. Base fire rate: %s, Final fire rate: %s" % [base_fire_rate, final_rate])

func attack(muzzle_position: Vector2, target_position: Vector2) -> void:
	if not _can_fire:
		return
	if not base_attack_data:
		printerr("WeaponComponent has no Base Attack Data assigned!")
		return

	_can_fire = false
	fire_rate_timer.start()

	var context := AttackContext.new()
	context.owner = get_owner() as Node2D
	context.muzzle_position = muzzle_position
	context.target_position = target_position

	context.attack_data = base_attack_data.duplicate(true)

	var shoot_direction := (target_position - muzzle_position).normalized()
	context.projectiles_to_spawn.append({
		"direction": shoot_direction,
		"attack_data": context.attack_data
	})

	for strategy in strategies:
		context = strategy.apply(context)

	for p_spawn_info in context.projectiles_to_spawn:
		_spawn_projectile(muzzle_position, p_spawn_info["direction"], p_spawn_info["attack_data"])

	emit_signal("recoil_shot", shoot_direction)

func _spawn_projectile(position: Vector2, direction: Vector2, attack_data: AttackData) -> void:
	var projectile_data = attack_data.duplicate(true)
	var new_projectile = projectile_data.projectile_scene.instantiate() as Bullet

	get_tree().root.add_child(new_projectile)
	new_projectile.launch(position, direction, projectile_data)
