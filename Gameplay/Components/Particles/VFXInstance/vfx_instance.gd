class_name VFXInstance
extends Node

@export var vfx_id: String = ""

# This script's only job is to free the effect scene when it's finished.

func _ready() -> void:
	if vfx_id.is_empty():
		push_warning("VFXInstance on '%s' has no vfx_id set!" % owner.name)
	var vfx_node = get_parent()

	# We need to explicitly check if the parent is valid before accessing its properties/signals.
	if is_instance_valid(vfx_node):
		if vfx_node is GPUParticles2D:
			# For particles, wait for the 'finished' signal.
			await vfx_node.finished
		elif vfx_node is AnimatedSprite2D:
			# For sprite animations, wait for the 'animation_finished' signal.
			await vfx_node.animation_finished

	# Self-destruction logic: queue_free the parent (the whole effect)
	if is_instance_valid(vfx_node):
		print("VFX ", vfx_id, " i am killing myself")
		vfx_node.queue_free()