extends CharacterBody2D

# Get a reference to the component that handles all the complex movement.
@onready var gravity_walker: GravityWalkerComponent = %GravityWalkerComponent

# --- You can keep all the other logic from the Dummy ---
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var hit_flash: HitFlash = %HitFlash

func _ready() -> void:
	# Connect signals just like the Dummy
	hurtbox.hit_recieved.connect(_on_hit_recieved)
	# You can add logic for what happens when health reaches zero here.

func _physics_process(delta: float):
	# The Patroller's only job is to tell the component to move.
	# All the complex logic is handled inside the component.
	gravity_walker.move(delta)

func _on_hit_recieved(data: AttackData, direction: Vector2):
	hit_flash.flash()
	# Apply knockback against the current surface normal
	var knockback_direction = (direction - _get_surface_normal() * direction.dot(_get_surface_normal())).normalized()
	velocity = knockback_direction * data.knockback_strength

# Helper to get the current orientation from the component
func _get_surface_normal() -> Vector2:
	if is_instance_valid(gravity_walker):
		return gravity_walker._surface_normal
	return Vector2.UP
