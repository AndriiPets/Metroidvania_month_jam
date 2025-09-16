extends Node
class_name HitFlash

## An array of CanvasItem nodes (like Sprite2D) that will flash.
@export var nodes_to_flash: Array[CanvasItem]

## How long the flash effect should last, in seconds.
@export var flash_duration: float = 0.08

# Preload the shader resource so it's ready to use. This is more
# efficient than loading it multiple times.
const HIT_FLASH_SHADER = preload("res://Gameplay/Components/HitFlash/hit_flash.gdshader")

var _tween: Tween

# This function now automatically sets up the materials for us.
func _ready() -> void:
	# Wait for the owner to be ready so we know all nodes are in the tree.
	await owner.ready

	for node in nodes_to_flash:
		# Ensure the node is a valid CanvasItem that can have a material.
		if not is_instance_valid(node):
			continue

		# Create a new, unique ShaderMaterial for this specific node.
		var material = ShaderMaterial.new()
		
		# Assign our preloaded shader to this new material.
		material.shader = HIT_FLASH_SHADER
		
		# Apply the fully configured material to the node.
		# This will overwrite any existing material.
		node.material = material

## Call this method to trigger the white flash effect.
func flash() -> void:
	# If a tween is already running, kill it to restart the flash.
	if is_instance_valid(_tween):
		_tween.kill()

	_tween = create_tween()

	# Set the flash_modifier to 1.0 (full white) instantly.
	for node in nodes_to_flash:
		if is_instance_valid(node) and node.material is ShaderMaterial:
			node.material.set_shader_parameter("flash_modifier", 1.0)

	# Then, create a tween to animate it back to 0.0 over the duration.
	for node in nodes_to_flash:
		if is_instance_valid(node) and node.material is ShaderMaterial:
			_tween.tween_property(
				node.material, "shader_parameter/flash_modifier", 0.0, flash_duration
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)