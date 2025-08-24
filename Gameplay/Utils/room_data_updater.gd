@tool
extends Node

## The RoomData .tres file that corresponds to this scene.
@export var room_data: RoomData

## Set the desired type for this room.
@export var room_type: RoomData.RoomType = RoomData.RoomType.NORMAL

# --- The Magic Button ---
## Press this to create or update the RoomData resource file for this scene.
@export var create_or_update_data: bool = false:
	set(value):
		if value:
			_create_or_update_room_data()
			# Reset the checkbox so it acts like a button.
			set("create_or_update_data", false)
			notify_property_list_changed()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not owner or not owner.scene_file_path:
		return warnings

	if not room_data:
		warnings.append("No RoomData resource is linked. Press 'Create or Update Data' to generate it.")
		return warnings

	# Check if the resource's scene path matches this scene.
	if not room_data.scene or room_data.scene.resource_path != owner.scene_file_path:
		warnings.append("The linked RoomData's scene path does not match this scene. Press the update button.")

	return warnings

func _create_or_update_room_data():
	var scene_root = owner if is_instance_valid(owner) else get_tree().edited_scene_root
	if not is_instance_valid(scene_root) or scene_root.scene_file_path.is_empty():
		push_warning("Cannot update. The scene must be saved first.")
		return

	var scene_path = scene_root.scene_file_path
	# Convention: Store RoomData in a parallel folder structure.
	var data_path = scene_path.replace("Rooms", "RoomData").replace(".tscn", ".tres")

	# --- 1. Create or Load the Resource ---
	if FileAccess.file_exists(data_path):
		print("Found existing RoomData at: %s. Loading it." % data_path)
		room_data = ResourceLoader.load(data_path, "RoomData", ResourceLoader.CACHE_MODE_REUSE)
	else:
		print("No RoomData found. Creating a new one at: %s" % data_path)
		var new_resource = RoomData.new()
		var save_err = ResourceSaver.save(new_resource, data_path)
		if save_err != OK:
			push_error("Failed to save new RoomData resource. Error: %s" % save_err)
			return
		room_data = load(data_path)

	if not room_data:
		push_error("Failed to load or create the RoomData resource.")
		return

	# --- 2. Update All Properties ---
	print("Updating RoomData properties...")
	
	# Update Scene Link
	room_data.scene = load(scene_path)
	
	# Update Room Type
	room_data.room_type = room_type

	# Update Dimensions
	var tilemap_node = _find_tilemap_node(scene_root)
	if tilemap_node:
		var used_rect = tilemap_node.get_used_rect()
		# Add a 1-unit buffer for consistency, as rect starts at 0,0
		room_data.size_units = used_rect.size + Vector2i.ONE
		print("  - Updated dimensions to: ", room_data.size_units)
	else:
		push_warning("Could not find a TileMapLayer node to calculate room dimensions.")

	# Update Exits
	var new_exits_array: Array[ExitData] = []
	var exit_nodes: Array = _find_exit_point_nodes(scene_root)
	
	for exit_node in exit_nodes:
		var new_exit_data = ExitData.new()
		new_exit_data.position = exit_node.position
		new_exit_data.direction = exit_node.direction
		new_exits_array.append(new_exit_data)
	
	room_data.exits = new_exits_array
	print("  - Found and updated %d exits." % exit_nodes.size())

	# --- 3. Save the Changes ---
	var final_save_err = ResourceSaver.save(room_data)
	if final_save_err != OK:
		push_error("Failed to save updated RoomData. Error: %s" % final_save_err)
	else:
		print("Successfully updated and saved RoomData for: ", room_data.resource_path)

	# Notify the editor that properties have changed to refresh the inspector.
	update_configuration_warnings()

# --- Helper Functions to find nodes ---

func _find_tilemap_node(start_node: Node) -> TileMap:
	if start_node is TileMap:
		return start_node
	for child in start_node.get_children():
		var found = _find_tilemap_node(child)
		if found:
			return found
	return null

func _find_exit_point_nodes(start_node: Node) -> Array:
	var found_nodes := []
	if start_node is ExitPoint:
		found_nodes.append(start_node)
	
	for child in start_node.get_children():
		found_nodes.append_array(_find_exit_point_nodes(child))
	
	return found_nodes