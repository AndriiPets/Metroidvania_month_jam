extends Node

enum State {IDLE, DRAFTING}
var current_state = State.IDLE

signal draft_options_ready(options)
signal placement_ended
signal preview_room_updated(room_data, room_scale) # MODIFIED: Now passes scale
signal player_room_changed

const TILE_SIZE := Vector2(32, 32)

var room_database: Array[RoomData] = []
var attached_node: Node = null
var dungeon_graph: Dictionary = {}
var instantiated_rooms: Dictionary = {}
var current_room_id: int = -1
var current_room_scene: Node2D = null
var next_room_id: int = 0
var _draft_context: Dictionary = {}

# --- MODIFIED: For Minimap and Previews ---
var ghost_room_data: RoomData = null
var ghost_grid_position: Vector2i = Vector2i.ZERO
var ghost_room_scale: Vector2 = Vector2.ONE # NEW: To store ghost's orientation

func init(node: Node, rooms_folder_path: String):
	set_level_node(node)
	for room_node in instantiated_rooms.values():
		if is_instance_valid(room_node): room_node.queue_free()
	instantiated_rooms.clear()
	dungeon_graph.clear()
	current_room_id = -1; current_room_scene = null; next_room_id = 0
	_draft_context.clear(); current_state = State.IDLE
	ghost_room_data = null
	ghost_room_scale = Vector2.ONE # Reset scale on init
	load_rooms_from_path(rooms_folder_path)

func start_dungeon():
	if not is_instance_valid(attached_node) or room_database.is_empty(): return
	var starting_room_data = room_database.front()
	var placed_room = _add_room_to_graph(starting_room_data, Vector2.ZERO)
	_instantiate_and_setup_room(placed_room)
	current_room_id = placed_room.unique_id
	current_room_scene = instantiated_rooms[current_room_id]
	emit_signal("player_room_changed")

func load_rooms_from_path(folder_path: String):
	room_database.clear(); var dir = DirAccess.open(folder_path)
	if not dir: return
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			var resource = load(folder_path.path_join(file_name))
			if resource is RoomData: room_database.append(resource)

func _instantiate_and_setup_room(placed_room: PlacedRoom):
	var scene_instance = load(placed_room.room_data.scene_path).instantiate()
	scene_instance.scale = placed_room.scale
	scene_instance.position = placed_room.world_position
	instantiated_rooms[placed_room.unique_id] = scene_instance
	attached_node.add_child(scene_instance)

	var room_area = scene_instance.find_child("RoomArea", true, false)
	if room_area and room_area is RoomArea:
		room_area.unique_id = placed_room.unique_id
		room_area.player_entered_room.connect(_on_player_entered_room)
	else:
		push_warning("Room scene %s is missing a RoomArea child!" % placed_room.room_data.scene_path)
		
	var doorways = scene_instance.find_children("*", "Doorway", true, false)
	for doorway in doorways:
		if doorway is Doorway:
			doorway.set_room_context(placed_room.unique_id)

func start_room_draft(origin_doorway: Doorway, origin_room_id: int, origin_exit_index: int):
	if current_state != State.IDLE: return
	current_state = State.DRAFTING
	_draft_context = {
		"origin_doorway_node": origin_doorway,
		"origin_room_id": origin_room_id,
		"origin_exit_index": origin_exit_index
	}
	var options = room_database.filter(func(r): return r.room_type == RoomData.RoomType.NORMAL)
	options.shuffle()
	var final_options = options.slice(0, 3)
	
	if not final_options.is_empty():
		update_draft_preview(final_options[0])
		
	emit_signal("draft_options_ready", final_options)

# --- MODIFIED: Now pre-calculates scale for accurate preview ---
func update_draft_preview(preview_data: RoomData):
	if current_state != State.DRAFTING: return
	
	ghost_room_data = preview_data
	
	var origin_room: PlacedRoom = dungeon_graph[_draft_context.origin_room_id]
	var origin_exit: ExitData = origin_room.room_data.exits[_draft_context.origin_exit_index]
	
	# Pre-calculate the connection to get the required scale for mirroring.
	var connection_result = _find_connecting_exit(preview_data, origin_exit.direction)
	ghost_room_scale = connection_result.get("scale", Vector2.ONE)

	var direction_vector = get_direction_vector(origin_exit.direction)
	ghost_grid_position = origin_room.grid_position + direction_vector
	
	emit_signal("preview_room_updated", preview_data, ghost_room_scale)

func confirm_draft_choice(chosen_room_data: RoomData):
	if current_state != State.DRAFTING: return

	var origin_room: PlacedRoom = dungeon_graph[_draft_context.origin_room_id]
	var origin_exit_data: ExitData = origin_room.room_data.exits[_draft_context.origin_exit_index]
	var origin_doorway: Doorway = _draft_context.origin_doorway_node

	var connection_result = _find_connecting_exit(chosen_room_data, origin_exit_data.direction)
	
	if not is_instance_valid(origin_doorway) or connection_result.is_empty():
		push_warning("Could not find a matching doorway (direct or mirrored). Aborting draft.")
		reset_state(); return

	var new_room_exit_index: int = connection_result.index
	var new_room_scale: Vector2 = connection_result.scale
	var new_room_exit_local_pos = chosen_room_data.exits[new_room_exit_index].position * new_room_scale

	var offset = Vector2(get_direction_vector(origin_exit_data.direction)) * TILE_SIZE
	var new_room_world_pos = origin_doorway.global_position - new_room_exit_local_pos + offset

	var connection_info = {
		"origin_room_id": origin_room.unique_id,
		"origin_exit_index": _draft_context.origin_exit_index,
		"new_room_exit_index": new_room_exit_index
	}
	
	var new_room = _add_room_to_graph(chosen_room_data, new_room_world_pos, new_room_scale, connection_info)
	_instantiate_and_setup_room(new_room)
	
	reset_state()

func _on_player_entered_room(new_room_id: int):
	call_deferred("_handle_room_transition", new_room_id)
	
func _handle_room_transition(new_room_id: int):
	if current_room_id == new_room_id:
		return
	print("Player has transitioned to Room %s" % new_room_id)
	current_room_id = new_room_id
	current_room_scene = instantiated_rooms[new_room_id]
	_load_neighboring_rooms()
	_cleanup_distant_rooms()
	emit_signal("player_room_changed")

func _load_neighboring_rooms():
	if not dungeon_graph.has(current_room_id): return
	var current_placed_room = dungeon_graph[current_room_id]
	for neighbor_id in current_placed_room.connections.values():
		if not instantiated_rooms.has(neighbor_id):
			print("Loading neighbor room: ", neighbor_id)
			var neighbor_room_data = dungeon_graph[neighbor_id]
			_instantiate_and_setup_room(neighbor_room_data)

func _cleanup_distant_rooms():
	var current_placed_room = dungeon_graph[current_room_id]
	var rooms_to_keep: Array[int] = [current_room_id]
	rooms_to_keep.append_array(current_placed_room.connections.values())
	for room_id in instantiated_rooms.keys():
		if not room_id in rooms_to_keep:
			var room_node_to_remove = instantiated_rooms[room_id]
			if is_instance_valid(room_node_to_remove):
				room_node_to_remove.queue_free()
			instantiated_rooms.erase(room_id)
			print("DungeonManager: Despawned distant room with ID: ", room_id)

func _add_room_to_graph(data: RoomData, world_pos: Vector2, room_scale: Vector2 = Vector2.ONE, connection_info: Dictionary = {}) -> PlacedRoom:
	var new_placed_room := PlacedRoom.new()
	new_placed_room.unique_id = next_room_id
	new_placed_room.room_data = data
	new_placed_room.world_position = world_pos
	new_placed_room.scale = room_scale

	if connection_info.is_empty():
		# This is the first room
		new_placed_room.grid_position = Vector2i.ZERO
	else:
		# This room is being connected to an existing one
		var origin_room: PlacedRoom = dungeon_graph[connection_info.origin_room_id]
		var origin_exit: ExitData = origin_room.room_data.exits[connection_info.origin_exit_index]
		var direction_vector = get_direction_vector(origin_exit.direction)
		new_placed_room.grid_position = origin_room.grid_position + direction_vector
		
		# Connect the rooms in the graph
		origin_room.connections[connection_info.origin_exit_index] = new_placed_room.unique_id
		new_placed_room.connections[connection_info.new_room_exit_index] = origin_room.unique_id

	dungeon_graph[new_placed_room.unique_id] = new_placed_room
	next_room_id += 1
	return new_placed_room

func _find_connecting_exit(room_data: RoomData, origin_dir: ExitData.Direction) -> Dictionary:
	var target_dir = get_opposite_direction(origin_dir)

	for i in range(room_data.exits.size()):
		if room_data.exits[i].direction == target_dir:
			return {"index": i, "scale": Vector2.ONE}

	var can_mirror_horizontally = (target_dir == ExitData.Direction.LEFT or target_dir == ExitData.Direction.RIGHT)
	if can_mirror_horizontally:
		var mirrored_equivalent = get_opposite_direction(target_dir)
		for i in range(room_data.exits.size()):
			if room_data.exits[i].direction == mirrored_equivalent:
				return {"index": i, "scale": Vector2(-1, 1)}
	
	var can_mirror_vertically = (target_dir == ExitData.Direction.UP or target_dir == ExitData.Direction.DOWN)
	if can_mirror_vertically:
		var mirrored_equivalent = get_opposite_direction(target_dir)
		for i in range(room_data.exits.size()):
			if room_data.exits[i].direction == mirrored_equivalent:
				return {"index": i, "scale": Vector2(1, -1)}
	
	return {}

func get_player() -> Player: return get_tree().get_first_node_in_group("player") as Player
func set_level_node(node: Node): attached_node = node
func reset_state():
	current_state = State.IDLE
	_draft_context.clear()
	ghost_room_data = null
	emit_signal("placement_ended")

func get_direction_vector(dir: ExitData.Direction) -> Vector2i:
	match dir:
		ExitData.Direction.RIGHT: return Vector2i.RIGHT
		ExitData.Direction.LEFT: return Vector2i.LEFT
		ExitData.Direction.UP: return Vector2i.UP
		ExitData.Direction.DOWN: return Vector2i.DOWN
	return Vector2i.ZERO

func get_opposite_direction(dir: ExitData.Direction) -> ExitData.Direction:
	match dir:
		ExitData.Direction.RIGHT: return ExitData.Direction.LEFT
		ExitData.Direction.LEFT: return ExitData.Direction.RIGHT
		ExitData.Direction.UP: return ExitData.Direction.DOWN
		ExitData.Direction.DOWN: return ExitData.Direction.UP
	return ExitData.Direction.RIGHT