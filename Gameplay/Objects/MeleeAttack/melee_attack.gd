extends Node2D
class_name MeleeHitboxArea

@onready var hitbox_component: HitboxComponent = %Hitbox
@onready var lifetime_timer: Timer = %AttackTimer

var _hit_targets = [] # List of hurtboxes already damaged by this swing.

func launch(data: AttackData, duration: float):
	_hit_targets.clear()
	hitbox_component.data = data
	lifetime_timer.wait_time = duration
	lifetime_timer.start()

func _ready() -> void:
	lifetime_timer.timeout.connect(queue_free)
	# The HitboxComponent is just a data container. We listen for the Area2D's signal.
	hitbox_component.area_entered.connect(_on_target_entered)

func _on_target_entered(hurtbox: Area2D):
	if not hurtbox is HurtboxComponent:
		return

	# Check if we have already hit this specific hurtbox instance in this swing
	if hurtbox in _hit_targets:
		return # Ignore it

	# If not, add it to the list and proceed with the damage logic
	_hit_targets.append(hurtbox)
