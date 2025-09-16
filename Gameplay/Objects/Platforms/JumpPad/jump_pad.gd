extends StaticBody2D

## The time in seconds before the jump pad reactivates.
@export var cooldown_duration: float = 2.0

@onready var jumper_component: JumperComponent = $JumperComponent
@onready var squasher: Squasher = $Squasher
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var platform_collider: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	jumper_component.player_launched.connect(_on_player_launched)
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	
	cooldown_timer.wait_time = cooldown_duration
	cooldown_timer.one_shot = true
	
	_set_active_state(true)

func _on_player_launched() -> void:
	# The JumperComponent has already safely disabled itself.
	# Play the launch animation.
	if is_instance_valid(squasher):
		squasher.start(Vector2(0.9, 0.4))
		# --- FIX: Wait for the animation to complete BEFORE hiding anything. ---
		await squasher.stopped
	
	# Now that the animation is finished, hide the platform and start the cooldown.
	_set_active_state(false)
	cooldown_timer.start()

func _on_cooldown_finished() -> void:
	sprite.visible = true
	
	if is_instance_valid(squasher):
		squasher.start(Vector2(0.3, 0.6))
		await squasher.stopped
	
	_set_active_state(true)

## Helper function to manage the active/inactive state of the platform.
func _set_active_state(is_active: bool) -> void:
	sprite.visible = is_active
	
	if is_instance_valid(platform_collider):
		platform_collider.call_deferred("set_disabled", not is_active)
	
	if is_active:
		jumper_component.enable()
	else:
		jumper_component.disable()