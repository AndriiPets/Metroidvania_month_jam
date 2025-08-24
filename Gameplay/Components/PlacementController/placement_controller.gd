extends Node

var ghost_instance: Node2D = null

func _ready():
	# When the DungeonManager is done, we clean up.
	DungeonManager.connect("placement_ended", _on_placement_ended)
	DungeonManager.connect("preview_room_updated", _on_preview_room_updated)

func _process(_delta):
	# Only run this logic when the manager is in the placing state.
	if DungeonManager.current_state != DungeonManager.State.DRAFTING:
		# If we are not drafting, ensure there is no ghost instance.
		if is_instance_valid(ghost_instance):
			ghost_instance.queue_free()
			ghost_instance = null
		return
	# Check if we need to create the ghost room instance.
	if not is_instance_valid(ghost_instance):
		if DungeonManager.ghost_room_data:
			create_ghost_instance(DungeonManager.ghost_room_data)

	if is_instance_valid(ghost_instance):
		# The DungeonManager calculates the correct snapped position.
		var calculated_pos = DungeonManager.calculate_ghost_position()
		ghost_instance.global_position = calculated_pos

		# We also ask the manager if this position is valid.
		var size_in_pixels = DungeonManager.ghost_room_data.size_units * DungeonManager.CELL_SIZE
		var proposed_rect = Rect2(calculated_pos, size_in_pixels)
		var is_valid = DungeonManager.is_placement_valid(proposed_rect)

		# Update the ghost's appearance based on validity.
		if is_valid:
			ghost_instance.modulate = Color(0.5, 1.0, 0.5, 0.5) # Green
		else:
			ghost_instance.modulate = Color(1.0, 0.5, 0.5, 0.5) # Red

func _on_preview_room_updated(data: RoomData):
	# Destroy the old ghost if it exists.
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()

	# Create the new one.
	create_ghost_instance(data)

func create_ghost_instance(data: RoomData):
	ghost_instance = data.scene.instantiate()
	ghost_instance.name = "GhostRoom"
	# Make sure it doesn't interfere with physics.
	# This assumes the root has a 'set_physics_process' method, which most Node2Ds do.
	# You might need to disable collision shapes more explicitly.
	ghost_instance.set_physics_process(false)
	add_child(ghost_instance)

# This is called by the signal from the DungeonManager.
func _on_placement_ended():
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null
