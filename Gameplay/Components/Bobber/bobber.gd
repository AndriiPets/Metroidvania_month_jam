class_name Bobber extends Node

signal started
signal stopped

# Define the different kinds of motion our Bobber can perform.
enum MotionType {
	ELLIPSE, # Standard circular/oval path (cos(t), sin(t))
	FIGURE_EIGHT # Downward arc / Lemniscate path (cos(t), sin(2t))
}

@export var nodes: Array[Node]
@export var enabled: bool = true
@export var duration: float = 1.0 # The time in seconds for one full animation cycle.
@export var inverse_x_on_odd_nodes: bool = false # NEW: If true, inverts X-motion for every other node.

var bob_amount: Vector2 = Vector2.ZERO
var _tween: Tween
var _initial_positions: Array[Vector2]
var _motion_type: MotionType = MotionType.ELLIPSE
var _speed_scale: float = 1.0

# The start function now accepts a speed scale parameter.
func start(amount: Vector2, motion: MotionType = MotionType.ELLIPSE, speed: float = 1.0) -> void:
	if not enabled:
		return

	# If we are already playing and the parameters haven't changed, do nothing.
	if is_instance_valid(_tween) and amount == bob_amount and motion == _motion_type and speed == _speed_scale:
		return
		
	# If parameters have changed, stop the old tween to start a new one.
	stop()
	
	bob_amount = amount
	_motion_type = motion
	_speed_scale = speed
	
	if nodes.is_empty():
		printerr("No nodes defined on %s " % self.name)
		return
	
	_initial_positions = []
	for node in nodes:
		if not node.has_method("get_position"):
			printerr("%s does not have a 'position' property." % node.name)
			return
		_initial_positions.push_back(node.position)
		
	_tween = create_tween().set_loops()
	_tween.set_speed_scale(_speed_scale) # NEW: Apply the speed control.
	_tween.tween_method(_update_bob_position, 0.0, 2.0 * PI, duration)
	
	started.emit()

# This method calculates the position, now with optional inversion.
func _update_bob_position(angle: float) -> void:
	if _initial_positions.is_empty():
		stop()
		return
		
	var base_offset: Vector2
	
	match _motion_type:
		MotionType.ELLIPSE:
			base_offset = Vector2(cos(angle), sin(angle)) * bob_amount
		MotionType.FIGURE_EIGHT:
			base_offset = Vector2(cos(angle) * bob_amount.x, sin(angle * 2) * bob_amount.y)
	
	for i in nodes.size():
		var final_offset = base_offset
		# NEW: Check if we need to invert the motion for this specific node.
		if inverse_x_on_odd_nodes and i % 2 != 0:
			final_offset.x *= -1.0
			
		nodes[i].position = _initial_positions[i] + final_offset

func stop() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
		_tween = null
		
	if not _initial_positions.is_empty():
		for i in nodes.size():
			nodes[i].position = _initial_positions[i]
		_initial_positions.clear()
		
	stopped.emit()