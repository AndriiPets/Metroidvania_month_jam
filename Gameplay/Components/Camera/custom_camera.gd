extends Camera2D
class_name SmoothCamera

## The node for the camera to follow.
@export var target: Node2D

## How quickly the camera catches up to the target on each axis.
## Lower values are smoother. X controls horizontal, Y controls vertical.
@export var smooth_factors: Vector2 = Vector2(0.1, 0.05)

## An optional offset from the target's position (e.g., to look ahead).
@export var position_offset: Vector2 = Vector2.ZERO

@export var shake_decay_rate: float = 15.0

var _current_shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	Globals.camera_shake_requested.connect(shake)

func _physics_process(delta: float) -> void:
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

	# --- Camera Shake Logic ---
	if _current_shake_strength > 0.1:
		# Gradually reduce the shake strength over time.
		_current_shake_strength = lerp(_current_shake_strength, 0.0, shake_decay_rate * delta)
		
		# Generate a random offset based on the current strength.
		var shake_offset = Vector2(\
			_rng.randf_range(-_current_shake_strength, _current_shake_strength), \
			_rng.randf_range(-_current_shake_strength, _current_shake_strength) \
		)
		# Apply the shake as a temporary offset to the camera.
		self.offset = shake_offset
	else:
		# Once the shake is negligible, reset strength and offset completely.
		_current_shake_strength = 0.0
		self.offset = Vector2.ZERO

## Starts a camera shake effect.
## [param strength] The initial intensity of the shake. A good starting value is 10-20.
func shake(strength: float) -> void:
	_current_shake_strength = strength