extends Control
class_name Minimap

# --- Constants for Drawing ---
const ROOM_SIZE = Vector2(30, 30)
const PADDING = 10.0
const WALL_THICKNESS = 3.0
const DOOR_SIZE = 8.0

# --- Color palette remains the same ---
const BACKGROUND_COLOR = Color(0.1, 0.1, 0.1, 0.8)
const WALL_COLOR = Color(0.6, 0.6, 0.6, 0.9)
const INTERIOR_COLOR = Color(0.3, 0.3, 0.3, 0.9)
const CURRENT_INTERIOR_COLOR = Color(0.2, 0.9, 0.2, 1.0)
const GHOST_WALL_COLOR = Color(1.0, 1.0, 1.0, 0.5)
const GHOST_INTERIOR_COLOR = Color(0.8, 0.8, 0.8, 0.4)

func _ready() -> void:
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	DungeonManager.connect("placement_ended", _on_dungeon_updated)
	DungeonManager.connect("preview_room_updated", _on_dungeon_updated)
	DungeonManager.connect("player_room_changed", _on_dungeon_updated)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("TOGGLE_MINIMAP"):
		visible = not visible
		if visible: queue_redraw()
		get_viewport().set_input_as_handled()

func _on_dungeon_updated(_data=null, _scale=Vector2.ONE): # Accept new args
	if visible: queue_redraw()

# --- NEW: Helper function to account for room mirroring ---
func _get_mirrored_direction(original_dir: ExitData.Direction, room_scale: Vector2) -> ExitData.Direction:
	var mirrored_dir = original_dir
	if room_scale.x < 0:
		if mirrored_dir == ExitData.Direction.RIGHT: mirrored_dir = ExitData.Direction.LEFT
		elif mirrored_dir == ExitData.Direction.LEFT: mirrored_dir = ExitData.Direction.RIGHT
	if room_scale.y < 0:
		if mirrored_dir == ExitData.Direction.UP: mirrored_dir = ExitData.Direction.DOWN
		elif mirrored_dir == ExitData.Direction.DOWN: mirrored_dir = ExitData.Direction.UP
	return mirrored_dir

func _draw() -> void:
	var graph = DungeonManager.dungeon_graph
	var current_room_id = DungeonManager.current_room_id
	if graph.is_empty() or not graph.has(current_room_id): return

	draw_rect(get_rect(), BACKGROUND_COLOR)

	var map_center = get_rect().size / 2.0
	var current_room_data = graph[current_room_id]
	var drawing_offset = map_center - (Vector2(current_room_data.grid_position) * ROOM_SIZE)

	for room in graph.values():
		var room_pos = Vector2(room.grid_position) * ROOM_SIZE + drawing_offset
		var room_rect = Rect2(room_pos, ROOM_SIZE)
		if not get_rect().intersects(room_rect): continue

		var interior_color = CURRENT_INTERIOR_COLOR if room.unique_id == current_room_id else INTERIOR_COLOR
		draw_rect(room_rect, WALL_COLOR)
		var interior_rect = Rect2(room_pos + Vector2(WALL_THICKNESS, WALL_THICKNESS), ROOM_SIZE - Vector2(WALL_THICKNESS, WALL_THICKNESS) * 2)
		draw_rect(interior_rect, interior_color)
		
		# --- MODIFIED: Draw doors with correct orientation ---
		for exit_data in room.room_data.exits:
			var actual_direction = _get_mirrored_direction(exit_data.direction, room.scale)
			_draw_door(room_pos, actual_direction)

	if DungeonManager.current_state == DungeonManager.State.DRAFTING:
		_draw_ghost_room(drawing_offset)

func _draw_door(room_pos: Vector2, direction: ExitData.Direction):
	var door_rect = Rect2()
	door_rect.size = Vector2(DOOR_SIZE, DOOR_SIZE)
	match direction:
		ExitData.Direction.RIGHT: door_rect.position = room_pos + Vector2(ROOM_SIZE.x - DOOR_SIZE / 2.0, ROOM_SIZE.y / 2.0 - DOOR_SIZE / 2.0)
		ExitData.Direction.LEFT: door_rect.position = room_pos + Vector2(-DOOR_SIZE / 2.0, ROOM_SIZE.y / 2.0 - DOOR_SIZE / 2.0)
		ExitData.Direction.UP: door_rect.position = room_pos + Vector2(ROOM_SIZE.x / 2.0 - DOOR_SIZE / 2.0, -DOOR_SIZE / 2.0)
		ExitData.Direction.DOWN: door_rect.position = room_pos + Vector2(ROOM_SIZE.x / 2.0 - DOOR_SIZE / 2.0, ROOM_SIZE.y - DOOR_SIZE / 2.0)
	draw_rect(door_rect, BACKGROUND_COLOR)

# --- MODIFIED: Now uses ghost_room_scale to draw exits correctly ---
func _draw_ghost_room(offset: Vector2):
	if DungeonManager.ghost_room_data == null: return

	var ghost_pos = Vector2(DungeonManager.ghost_grid_position) * ROOM_SIZE + offset
	var ghost_scale = DungeonManager.ghost_room_scale

	draw_rect(Rect2(ghost_pos, ROOM_SIZE), GHOST_WALL_COLOR)
	var interior_rect = Rect2(ghost_pos + Vector2(WALL_THICKNESS, WALL_THICKNESS), ROOM_SIZE - Vector2(WALL_THICKNESS, WALL_THICKNESS) * 2)
	draw_rect(interior_rect, GHOST_INTERIOR_COLOR)

	for exit_data in DungeonManager.ghost_room_data.exits:
		var actual_direction = _get_mirrored_direction(exit_data.direction, ghost_scale)
		_draw_door(ghost_pos, actual_direction)

	var origin_room: PlacedRoom = DungeonManager.dungeon_graph[DungeonManager._draft_context.origin_room_id]
	var origin_exit_dir = origin_room.room_data.exits[DungeonManager._draft_context.origin_exit_index].direction
	var origin_room_pos = Vector2(origin_room.grid_position) * ROOM_SIZE + offset
	_draw_door(origin_room_pos, origin_exit_dir)