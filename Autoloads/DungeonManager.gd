extends Node

enum State {IDLE, DRAFTING}
var current_state = State.IDLE

#SIGNALS
signal draft_options_ready(options, exit_data)
signal preview_room_updated(room_data)
signal placement_ended

const CELL_SIZE := Vector2(16, 16)

var room_database: Array[RoomData] = []
var attached_node: Node = null
var placed_rooms: Array = []

var ghost_room_data: RoomData = null
var _origin_exit_global_pos: Vector2 = Vector2.ZERO
var _origin_exit_direction: ExitData.Direction = ExitData.Direction.RIGHT

func init(node: Node, rooms_folder_path: String) -> void:
	set_level_node(node)
	load_rooms_from_path(rooms_folder_path)
	print("DungeonManager initialized with ", room_database.size(), " rooms.")

## Parses a folder for all .tres files and loads them if they are RoomData resources.
func load_rooms_from_path(folder_path: String) -> void:
	# Clear any previously loaded data to prevent duplicates.
	room_database.clear()

	var dir := DirAccess.open(folder_path)
	if not dir.dir_exists(folder_path):
		push_error("DungeonManager: Could not open directory at path: %s" % folder_path)

	dir.list_dir_begin() # Skip "." and ".." and hidden files
	var file_name := dir.get_next()

	while file_name != "":
			# We only care about resource files.
		if file_name.ends_with(".tres"):
			var resource_path = folder_path.path_join(file_name)
			var resource := load(resource_path)

				# IMPORTANT: Check if the loaded resource is the type we want.
			if resource is RoomData:
				room_database.append(resource)
			else:
					# This warning is helpful for debugging your content folder.
				printerr("DungeonManager: Found a .tres file that is not RoomData at: %s" % resource_path)

		file_name = dir.get_next()

#####################################################################

## STEP 1: Called by an ExitPoint when the player enters it. Begins the draft process.
func start_room_draft(exit_global_pos: Vector2, exit_direction: ExitData.Direction) -> void:
	if current_state != State.IDLE:
		return # Avoid starting a new draft if one is already in progress.

	current_state = State.DRAFTING
	_origin_exit_global_pos = exit_global_pos
	_origin_exit_direction = exit_direction

	# Generate a list of rooms to offer the player.
	# This logic can be as simple or complex as you want.
	var draft_options: Array[RoomData] = get_draft_options()

	var exit_data = {"position": _origin_exit_global_pos, "direction": _origin_exit_direction}
	emit_signal("draft_options_ready", draft_options, exit_data)

## STEP 2: Called by the RoomDraftUI when the player clicks a room choice.
func update_room_preview(room_data: RoomData):
	if current_state != State.DRAFTING:
		return
	ghost_room_data = room_data
	emit_signal("preview_room_updated", ghost_room_data)

## STEP 3: Called by the PlacementController when the player confirms a valid placement.
func confirm_draft_placement() -> void:
	if current_state != State.DRAFTING:
		return

	# Use the currently previewed ghost data to place the real room.
	var placement_position = calculate_ghost_position()

	if placement_position == Vector2.INF:
		printerr("DungeonManager: Could not find valid exit on previewed room. Aborting.")
		reset_state()
		return

	var size_in_pixels = ghost_room_data.size_units * CELL_SIZE
	var proposed_rect = Rect2(placement_position, size_in_pixels)

	if is_placement_valid(proposed_rect):
		place_room(ghost_room_data, placement_position)
		reset_state()
	else:
		# If the final placement is invalid for some reason (e.g. another player action),
		# we still reset the state to avoid getting stuck.
		printerr("DungeonManager: Final placement position was invalid. Aborting.")
		reset_state()

##########################################################################
# HELPERS

func reset_state() -> void:
	current_state = State.IDLE
	ghost_room_data = null
	_origin_exit_global_pos = Vector2.ZERO

	emit_signal("placement_ended")

func get_draft_options(count: int = 3) -> Array[RoomData]:
	var normal_rooms := find_rooms_by_type(RoomData.RoomType.NORMAL)
	normal_rooms.shuffle()

	var options: Array[RoomData] = []
	for i in range(min(count, normal_rooms.size())):
		options.append(normal_rooms[i])
	return options

## Instantiates and adds a room scene to the level.
func place_room(data: RoomData, room_position: Vector2) -> void:
	# We must have a valid level node to add children to.
	if not is_instance_valid(attached_node):
		push_error("DungeonManager: Cannot place room, current_level_node is not set!")
		return

	if not data.scene:
		push_error("DungeonManager: The provided RoomData resource '%s' is missing its scene!" % data.resource_path)
		return

	var new_room_instance := data.scene.instantiate() as Node2D
	new_room_instance.position = room_position
	attached_node.add_child(new_room_instance)

	# Store the room's data and its bounding box for future collision checks.
	placed_rooms.append({
		"data": data,
		"rect": Rect2(room_position, data.size_units * CELL_SIZE)
	})

func find_rooms_by_type(type: RoomData.RoomType) -> Array[RoomData]:
	var found_rooms: Array[RoomData] = []
	for room_data in room_database:
		if room_data.room_type == type:
			found_rooms.append(room_data)
	return found_rooms

func set_level_node(node: Node) -> void:
	attached_node = node

func calculate_ghost_position() -> Vector2:
	if not ghost_room_data:
		return Vector2.INF # Return an invalid position if no data is set.

	var target_dir: ExitData.Direction = get_opposite_direction(_origin_exit_direction)

	# Iterate through the strongly-typed ExitData resources.
	# This is safer and clearer than iterating through generic dictionaries.
	for exit_data in ghost_room_data.exits:
		if exit_data.direction == target_dir:
			# Formula: New Room Position = Origin Exit's Global Position - Target Exit's Local Position
			return _origin_exit_global_pos - exit_data.position

	# If no compatible exit was found on the ghost room, return an invalid position
	# so the visual preview remains "red" and cannot be placed.
	return Vector2.INF

func is_placement_valid(proposed_rect: Rect2) -> bool:
	for room in placed_rooms:
		# The 'intersects' method is perfect for this AABB check.
		if room.rect.intersects(proposed_rect):
			return false # Collision detected!
	return true # No collisions, placement is valid.

## Called by the Player when they press DOWN again to cancel the draft.
func cancel_draft() -> void:
	if current_state == State.DRAFTING:
		reset_state()

func get_opposite_direction(dir: ExitData.Direction) -> ExitData.Direction:
	match dir:
		ExitData.Direction.RIGHT: return ExitData.Direction.LEFT
		ExitData.Direction.LEFT: return ExitData.Direction.RIGHT
		ExitData.Direction.UP: return ExitData.Direction.DOWN
		ExitData.Direction.DOWN: return ExitData.Direction.UP
	return ExitData.Direction.RIGHT
