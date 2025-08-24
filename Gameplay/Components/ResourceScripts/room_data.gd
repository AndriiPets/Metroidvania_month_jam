extends Resource
class_name RoomData

enum RoomType {NORMAL, BOSS, KEY}

@export var scene: PackedScene
@export var room_type: RoomType
@export var size_units: Vector2 = Vector2.ONE
@export var exits: Array[ExitData] = []