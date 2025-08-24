extends Resource
class_name ExitData

@export var position: Vector2 = Vector2.ZERO

enum Direction {RIGHT, LEFT, UP, DOWN}
@export var direction: Direction = Direction.RIGHT
