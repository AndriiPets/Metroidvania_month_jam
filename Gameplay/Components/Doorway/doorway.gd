extends Area2D
class_name Doorway

@export var exit_index: int = -1
@export var direction: ExitData.Direction = ExitData.Direction.RIGHT

var _my_room_id: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

# This function is still needed for the manager to tell the doorway which room it belongs to.
func set_room_context(room_id: int):
	_my_room_id = room_id

func _on_body_entered(body: Node) -> void:
	if not body is Player or _my_room_id == -1:
		return

	# --- NEW, SIMPLIFIED LOGIC ---
	# Always check the dungeon graph for the most up-to-date connection status.
	var is_room_connected: bool = false
	if DungeonManager.dungeon_graph.has(_my_room_id):
		var my_room_data: PlacedRoom = DungeonManager.dungeon_graph[_my_room_id]
		if my_room_data.connections.has(exit_index):
			is_room_connected = true

	# If the doorway is connected, the player can pass through freely. Do nothing.
	if is_room_connected:
		return
	
	# If it's NOT connected, it's a frontier. Start the drafting process.
	if $CollisionShape2D.disabled:
		return
		
	# Disable the collision shape to prevent multiple triggers.
	$CollisionShape2D.call_deferred("set_disabled", true)
	
	# Start the draft.
	DungeonManager.call_deferred("start_room_draft", self, _my_room_id, exit_index)