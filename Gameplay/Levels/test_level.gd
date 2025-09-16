extends Node2D

const ROOM_DATA_FOLDER = "res://Gameplay/Levels/RoomData/"

func _ready():
	# Initialize the manager with this node as the parent for rooms
	DungeonManager.init(self, ROOM_DATA_FOLDER)

	# Tell the manager to create and load the first room
	DungeonManager.start_dungeon()
