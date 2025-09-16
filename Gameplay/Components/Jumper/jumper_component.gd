extends Area2D
class_name JumperComponent

## The vertical velocity to apply to the player upon collision.
@export var launch_velocity: float = -700.0

signal player_launched

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		var player := body as Player
		player.velocity.y = launch_velocity
		
		# --- FIX: Disable immediately upon launch ---
		# This prevents the component from being triggered again in the same frame.
		disable()
		
		player_launched.emit()

## Enables the jumper, allowing it to detect and launch the player.
func enable() -> void:
	if is_instance_valid(collision_shape):
		collision_shape.call_deferred("set_disabled", false)

## Disables the jumper, preventing it from launching the player.
func disable() -> void:
	if is_instance_valid(collision_shape):
		collision_shape.call_deferred("set_disabled", true)