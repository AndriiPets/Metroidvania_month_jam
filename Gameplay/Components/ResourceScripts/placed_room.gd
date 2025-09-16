class_name PlacedRoom
extends Resource

## A unique identifier for this specific room instance (e.g., 0, 1, 2...).
var unique_id: int = -1

## Stores the room's orientation. (e.g., (-1, 1) for a horizontal flip).
var scale: Vector2 = Vector2.ONE

## A reference to the RoomData resource that defines this room's layout.
var room_data: RoomData

## The room's actual world position of the scene's origin.
var world_position: Vector2 = Vector2.ZERO

## Stores the connections to other rooms.
## Key: The exit index from this room's RoomData.exits array.
## Value: The unique_id of the PlacedRoom it connects to.
var connections: Dictionary = {}

## The room's position on a conceptual grid for minimap generation.
var grid_position: Vector2i = Vector2i.ZERO
