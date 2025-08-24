extends Camera2D
class_name SmoothCamera

## The node for the camera to follow.
@export var target: Node2D

## How quickly the camera catches up to the target on each axis.
## Lower values are smoother. X controls horizontal, Y controls vertical.
@export var smooth_factors: Vector2 = Vector2(0.1, 0.05)

## An optional offset from the target's position (e.g., to look ahead).
@export var position_offset: Vector2 = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		# If the target is not set or has been freed, do nothing.
		return
	
	# Calculate the desired final position, including any offset.
	var target_position = target.global_position + position_offset
	
	# Instead of lerping the entire vector at once, we now lerp each
	# component separately using its own smooth factor.
	var new_camera_pos: Vector2
	new_camera_pos.x = lerp(global_position.x, target_position.x, smooth_factors.x)
	new_camera_pos.y = lerp(global_position.y, target_position.y, smooth_factors.y)
	
	# Apply the newly calculated position to the camera.
	global_position = new_camera_pos