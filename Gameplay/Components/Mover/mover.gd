extends Node
class_name MoverComponent

## The AnimatableBody2D node to be moved by this component.
@export var target_node: AnimatableBody2D

## A Marker2D defining the end position of the movement.
@export var end_marker: Marker2D

## The time in seconds for one full back-and-forth cycle.
@export var duration: float = 4.0

## The transition type for the easing function (e.g., Linear, Sine, Circ).
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE

## The ease type for the easing function (e.g., In, Out, In-Out).
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

func _ready() -> void:
	_start_tween()

func _start_tween() -> void:
	if not is_instance_valid(target_node):
		push_warning("MoverComponent: Target node is not assigned or is invalid.")
		return

	if not is_instance_valid(end_marker):
		push_warning("MoverComponent: End position marker is not assigned or is invalid.")
		return

	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	var start_pos := target_node.position
	var end_pos := end_marker.position

	# Apply the exported easing and transition types to the tween.
	tween.tween_property(target_node, "position", end_pos, duration / 2.0) \
		 .set_trans(transition_type).set_ease(ease_type)
	tween.tween_property(target_node, "position", start_pos, duration / 2.0) \
		 .set_trans(transition_type).set_ease(ease_type)
