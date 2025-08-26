class_name Squasher extends Node

signal started
signal stopped

@export var nodes: Array[Node]
@export var enabled: bool = true
@export var squash_amount: Vector2 = Vector2(2.7, 1.3)
@export var random_offset: Vector2 = Vector2(0, 0)
@export_range(0, 25) var speed: float = 10
@export_range(0, 25) var cooldown: float = 0.2

var _playing: bool = false
var _initial_scales: Array[Vector2]
var _cooldown_timer: float = 0 # allows you to set a cooldown period to avoid accidental re-triggering of effect

func _process(delta: float) -> void:
	if !enabled:
		stop()
		return
		
	_cooldown_timer += delta
	if _playing:
		var _finished: bool = true
		for i in nodes.size():
			nodes[i].scale = lerp(nodes[i].scale, _initial_scales[i], delta * speed)
			if abs(nodes[i].scale.x - _initial_scales[i].x) >= 0.01 or abs(nodes[i].scale.y - _initial_scales[i].y) >= 0.01:
				_finished = false
		if _finished:
			stop()

func start(amount: Vector2 = Vector2(0.7, 1.3)) -> void:
	if _cooldown_timer > cooldown:
	# don't start if no nodes have been defined
		if nodes.size() == 0:
			printerr("No nodes defined on %s " % self.name)
			return
		
		squash_amount = amount
		# I originally had the nodes array typed to Node2D but that leaves out Control nodes... if anyone has a better idea
		# to implement both without a check like this, let me know -> sean@baconandgames.com
		for node in nodes:
			if !node.get("scale"):
				printerr("%s does not define the property 'scale' and thus cannot be used with EasySS" % node.name)
				return
		
		stop() # resets everything to initial scale before start, in case we're interrupting an in-progress bloop
		# capture starting scales so we know what to squash/stretch back to
		_initial_scales = []
		for i in nodes.size():
			_initial_scales.push_back(nodes[i].scale)
			nodes[i].scale = Vector2(randf_range(squash_amount.x - random_offset.x, squash_amount.x + random_offset.x), randf_range(squash_amount.y - random_offset.y, squash_amount.y + random_offset.y))
		_playing = true
		_cooldown_timer = 0
		started.emit()

# will interrupt ss and reset to intial values
func stop() -> void:
	if _initial_scales.size() > 0:
		for i in nodes.size():
			nodes[i].scale = _initial_scales[i]
		_playing = false
		stopped.emit()
