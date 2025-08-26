class_name AttackContext extends RefCounted

var owner: Node2D # Who is firing (the Player or an Enemy)
var muzzle_position: Vector2 # Global position where projectiles spawn
var target_position: Vector2 # Global position the weapon is aiming at
var attack_data: AttackData

var fire_rate_reduction_percentage: float = 0.0
## An array of dictionaries. Each dictionary defines one projectile to be spawned.
## Strategies will add to or modify the dictionaries in this array.
var projectiles_to_spawn: Array[Dictionary] = []
