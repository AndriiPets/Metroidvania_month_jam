extends RefCounted
class_name InputComponent

static func get_input_vector() -> Vector2:
	var input: Vector2 = Vector2.ZERO
	input.x = Input.get_axis("LEFT", "RIGHT")
	return input