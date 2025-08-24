extends Area2D
class_name ExitPoint

@export var direction: ExitData.Direction = ExitData.Direction.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#if not Engine.is_editor_hint():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body is not Player:
		return
	var player := body as Player
	player.on_exit_entered(self)

func _on_body_exited(body):
	if body is not Player:
		return
	var player := body as Player
	player.on_exit_exited()
