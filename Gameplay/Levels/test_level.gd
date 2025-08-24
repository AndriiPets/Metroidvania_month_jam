extends Node2D

const ROOM_DATA_FOLDER = "res://Gameplay/Levels/RoomData/"

func _ready():
	# Initialize the global DungeonManager as soon as the level is ready.
	# 'self' refers to this Level node, which is where rooms will be added.
	DungeonManager.init(self, ROOM_DATA_FOLDER)

	# Now that it's initialized, you can use it.
	# For example, place the very first room of the game.
	var starting_room_data = DungeonManager.find_rooms_by_type(RoomData.RoomType.NORMAL).front()
	if starting_room_data:
		DungeonManager.place_room(starting_room_data, Vector2.ZERO)
