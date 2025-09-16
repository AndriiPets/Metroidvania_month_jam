# File: Gameplay/AI/MovementComponents/gravity_walker_component.gd
class_name GravityWalkerComponent
extends Node2D

## --- NEW: Selectable movement behavior ---
enum MovementMode {
	FLOOR_WALK, # Original behavior: walk on floors, turn at walls/ledges.
	SURFACE_STICK # New behavior: stick to any surface and walk along it.
}
@export var movement_mode: MovementMode = MovementMode.SURFACE_STICK

@export var target_body: CharacterBody2D
@export var speed: float = 80.0
## --- NEW: Controls rotation speed for Surface Stick mode ---
@export var turn_speed: float = 10.0

@export var initial_direction: int = 1:
	set(value):
		_direction = sign(value) # Ensure it's only 1 or -1

@onready var wall_probe: RayCast2D = %WallProbe
@onready var floor_probe: RayCast2D = %FloorProbe
@onready var turn_cooldown: Timer = $TurnCooldown

var _direction: int = 1
var _gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _can_turn: bool = true

# The normal of the surface the character is aligned to. Will always be axis-aligned.
var _surface_normal: Vector2 = Vector2.UP

func _ready() -> void:
	if not target_body:
		push_warning("GravityWalkerComponent has no target_body assigned!")
		set_physics_process(false)
		return
	
	if _direction == -1:
		target_body.scale.x = -1
	
	turn_cooldown.timeout.connect(func():
		_can_turn=true
	)
	
	# Initialize surface normal based on the character's starting rotation
	_surface_normal = - target_body.transform.y.normalized()

func move(delta: float) -> void:
	if not is_instance_valid(target_body):
		return

	match movement_mode:
		MovementMode.FLOOR_WALK:
			_move_floor_walk(delta)
		MovementMode.SURFACE_STICK:
			_move_surface_stick(delta)

func _move_floor_walk(delta: float) -> void:
	if not target_body.is_on_floor():
		target_body.velocity.y += _gravity * delta
	
	if _can_turn && target_body.is_on_floor():
		if wall_probe.is_colliding():
			_turn_around()
		elif not floor_probe.is_colliding():
			_turn_around()

	target_body.velocity.x = speed * _direction
	target_body.move_and_slide()

func _move_surface_stick(delta: float) -> void:
	# keep probes aligned with the target_body so their casts are meaningful
	if is_instance_valid(target_body):
		# ensure the probes originate at the character and rotate with it
		var gpos = target_body.global_position
		var grot = target_body.global_rotation
		wall_probe.global_position = gpos
		floor_probe.global_position = gpos
		# make the probes point relative to the body's rotation
		wall_probe.global_rotation = grot
		floor_probe.global_rotation = grot
		# ensure the probes are enabled
		wall_probe.enabled = true
		floor_probe.enabled = true

	# --- 1. Check for Rotation Triggers ---
	if _can_turn:
		# Inner Corner: hit something with the wall probe -> turn into the wall.
		if wall_probe.is_colliding():
			print("WALKER: ran into the wall -> rotating")
			# clockwise if moving left (-1), counter-clockwise if moving right (1)
			_rotate_90_degrees(_direction < 0) # <- FIXED: explicit boolean, no 'not' precedence issues
			
		# Outer Corner: floor probe finds nothing -> turn around the edge.
		elif not floor_probe.is_colliding():
			print("WALKER: ran into the fall -> rotating")
			_rotate_90_degrees(_direction > 0)

	# --- 2. Apply Rotation (smoothly) ---
	var target_rotation = _surface_normal.angle() + PI / 2.0
	target_body.rotation = lerp_angle(target_body.rotation, target_rotation, delta * turn_speed)

	# --- 3. Apply Movement along the rotated body ---
	var forward_vector = Vector2.RIGHT.rotated(target_body.rotation)
	target_body.velocity = forward_vector * speed * _direction
	target_body.move_and_slide()

# --- REPLACEMENT: _rotate_90_degrees unchanged except clearer boolean handling/snapping ---
func _rotate_90_degrees(clockwise: bool) -> void:
	_can_turn = false
	turn_cooldown.start()
	var angle = PI / 2.0
	if clockwise:
		_surface_normal = _surface_normal.rotated(angle)
	else:
		_surface_normal = _surface_normal.rotated(-angle)

	# Snap to nearest axis to avoid drift
	_surface_normal = _surface_normal.snapped(Vector2(1, 1))

func _turn_around() -> void:
	_can_turn = false
	turn_cooldown.start()

	_direction *= -1
	target_body.scale.x *= -1

func _draw() -> void:
	draw_line(Vector2.ZERO, wall_probe.target_position, Color.RED, 2)
	draw_line(Vector2.ZERO, floor_probe.target_position, Color.BLUE, 2)

func _process(_delta: float) -> void:
	queue_redraw()
