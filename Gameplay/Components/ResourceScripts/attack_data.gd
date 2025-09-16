class_name AttackData extends Resource

enum AttachTarget {WORLD, OWNER}

@export var attach_to: AttachTarget = AttachTarget.WORLD
@export var damage: float = 1.0
@export var speed: float = 600.0
@export var knockback_strength: float = 40.0
@export var projectile_scene: PackedScene
@export var duration: float = 0.3 # How long the melee hitbox stays active, in seconds.