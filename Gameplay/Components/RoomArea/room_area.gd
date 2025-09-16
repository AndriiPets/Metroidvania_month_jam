extends Area2D
class_name RoomArea

# This will be set by the DungeonManager when the room is instantiated.
var unique_id: int = -1

signal player_entered_room(room_id)

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body is Player:
        # We only emit the signal if the player is entering a NEW room.
        if unique_id != -1 and DungeonManager.current_room_id != unique_id:
            emit_signal("player_entered_room", unique_id)