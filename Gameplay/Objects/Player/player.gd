# Gameplay/Objects/Player/player.gd

extends CharacterBody2D
class_name Player

# --- Movement Variables ---
var speed: float = 200.0

@export var jump_height := 80.0
@export var jump_time_to_peak := 0.3
@export var jump_time_to_descent := 0.4
@export var jump_distance := 120.0
@onready var jump_speed := calculate_jump_speed(jump_height, jump_time_to_peak)
@onready var up_gravity := calculate_jump_gravity(jump_height, jump_time_to_peak)
@onready var fall_gravity := calculate_fall_gravity(jump_height, jump_time_to_descent)
@onready var horizontal_speed := calculate_jump_horizontal_speed(jump_distance, jump_time_to_peak, jump_time_to_descent)

var bullet = preload("res://Gameplay/Objects/Bullet/bullet.tscn")

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var friction = 0.12
var acceleration = 0.25

var current_exit_point: ExitPoint = null

var was_on_floor: bool = true
var is_running: bool = false

var run_vfx_timer: Timer

# Get references to the new nodes in the scene tree.
@onready var body: AnimatedSprite2D = %Body
@onready var head: Sprite2D = %Head
@onready var weapon_pivot: Node2D = %WeaponPivot
@onready var muzzle: Marker2D = %WeaponPivot/Weapon/Muzzle

# Define constants for the head frames to make the code clearer.
# Make sure these numbers match the order in your spritesheet!
const HEAD_FRAME_STRAIT = 16
const HEAD_FRAME_UP = 24
const HEAD_FRAME_DOWN = 8
const HEAD_FRAME_STRAIT_SIDE = 17
const HEAD_FRAME_UP_SIDE = 25
const HEAD_FRAME_DOWN_SIDE = 9

var health: HeathComponent = HeathComponent.new()

func _ready() -> void:
	health.health_changed.connect(on_health_change)
	add_to_group("player")

	# Setup the timer for the running VFX
	run_vfx_timer = Timer.new()
	run_vfx_timer.wait_time = 0.5
	run_vfx_timer.timeout.connect(_on_run_vfx_timer_timeout)
	add_child(run_vfx_timer)

func _process(_delta: float) -> void:
	# Visual updates like aiming are best handled in _process.
	# This ensures they are smooth and not tied to the physics framerate.
	handle_aiming_and_head()

func _physics_process(delta: float) -> void:
	if DungeonManager.current_state != DungeonManager.State.IDLE:
		velocity = Vector2.ZERO # Stop movement when drafting
		body.play("idle")
		return

	# Handle Gravity
	if velocity.y <= 0.0:
		velocity.y += up_gravity * delta
	else:
		velocity.y += fall_gravity * delta

	# Handle Horizontal Movement
	var dir := InputComponent.get_input_vector().x
	handle_horizontal_movement(dir)
	handle_body_animation(dir)

	# Handle Jumping
	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		_execute_jump()

	# Handle Shooting
	if Input.is_action_just_pressed("SHOOT"):
		var b = bullet.instantiate() as Bullet

		# The direction is the forward vector of the pivot, ensuring the bullet
		# fires perfectly straight from the weapon's barrel.
		var shoot_direction = weapon_pivot.global_transform.x.normalized()

		# The spawn position is now the global position of our Muzzle marker.
		var spawn_position = muzzle.global_position

		# Launch the bullet from the correct position and with the correct direction.
		b.launch(spawn_position, shoot_direction, 300)
		get_tree().root.add_child(b)

	move_and_slide()

	_update_body_animation()
	was_on_floor = is_on_floor()

# --- NEW: Aiming and Head Control ---
func handle_aiming_and_head() -> void:
	# Get the angle from the weapon's pivot point to the global mouse position.
	var angle_to_mouse = (get_global_mouse_position() - weapon_pivot.global_position).angle()

	# 1. Rotate the weapon pivot to point at the mouse.
	weapon_pivot.rotation = angle_to_mouse

	# 2. Determine if we should flip the sprites based on mouse position.
	var should_flip = get_global_mouse_position().x < self.global_position.x
	head.flip_h = should_flip

	# Flipping the pivot's Y scale is a clever trick to flip the child weapon
	# without messing up the rotation.
	if should_flip:
		weapon_pivot.scale.y = -1
	else:
		weapon_pivot.scale.y = 1

	# 3. Update the head sprite frame based on the aiming angle.
	var angle_deg = rad_to_deg(angle_to_mouse)

	# To simplify the logic, we "normalize" the angle as if the player is always
	# facing right. An angle of 170 (almost left) becomes 10, for example.
	if should_flip:
		angle_deg = 180 - angle_deg
		# Keep the angle within the -180 to 180 range.
		if angle_deg > 180: angle_deg -= 360

	# Now we can select a frame based on simple angle ranges.
	# These ranges determine which "slice" of the aiming circle corresponds to which frame.
	# You can adjust these values to your liking!
	if angle_deg > -25 and angle_deg < 25:
		head.frame = HEAD_FRAME_STRAIT_SIDE # Looking straight ahead
	elif angle_deg >= 25 and angle_deg < 65:
		head.frame = HEAD_FRAME_DOWN_SIDE # Looking diagonally down
	elif angle_deg <= -25 and angle_deg > -65:
		head.frame = HEAD_FRAME_UP_SIDE # Looking diagonally up
	elif angle_deg >= 65:
		head.frame = HEAD_FRAME_DOWN # Looking straight down
	elif angle_deg <= -65:
		head.frame = HEAD_FRAME_UP # Looking straight up
	# Note: The 'strait' frame is unused in this aiming logic. You might use it for
	# an idle state where the player is not aiming and looks at the camera.

# --- NEW: Body Animation Control ---
func handle_body_animation(dir: float) -> void:
	# This logic is now only for the body sprite.
	if dir != 0:
		body.flip_h = (dir < 0)
		body.play("run")
	else:
		# is_on_floor() check prevents playing idle mid-air
		if is_on_floor():
			body.play("idle")

func on_health_change(old: int, new: int) -> void:
	print("Health changed : %s -> %s" % [old, new])

#---DRAFTING---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("DOWN"):
		if DungeonManager.current_state == DungeonManager.State.IDLE and is_instance_valid(current_exit_point):
			DungeonManager.start_room_draft(current_exit_point.global_position, current_exit_point.direction)
			get_viewport().set_input_as_handled()

		elif DungeonManager.current_state == DungeonManager.State.DRAFTING:
			DungeonManager.cancel_draft()
			get_viewport().set_input_as_handled()

func on_exit_entered(exit_point: ExitPoint):
	current_exit_point = exit_point

func on_exit_exited():
	current_exit_point = null

func handle_horizontal_movement(dir: float) -> void:
	if dir != 0:
		velocity.x = lerp(velocity.x, dir * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction)
	# move_and_slide() is now called once at the end of _physics_process

func _execute_jump() -> void:
	# Temporarily disable physics processing to prevent movement during the animation.
	set_physics_process(false)

	body.play("takeoff")
	VFXManager.spawn_vfx("takeoff", global_position)
	await body.animation_finished

	# Apply the jump velocity *after* the animation is complete.
	velocity.y = jump_speed
	var dir = InputComponent.get_input_vector().x
	velocity.x = sign(dir) * horizontal_speed

	# Re-enable the physics process to continue the game.
	set_physics_process(true)

# --- NEW: Unified Body Animation Logic ---
func _update_body_animation() -> void:
	var just_landed = is_on_floor() and not was_on_floor

	# Priority 1: Play landing animation. This overrides everything else.
	if just_landed:
		body.play("land")
		var landing_pos := global_position + Vector2(0, 16)
		VFXManager.spawn_vfx("land", landing_pos)
		return

	# If a one-shot animation is playing (like takeoff or land), let it finish.
	# Don't let other states interrupt it.
	if body.animation in ["takeoff", "land"]:
		run_vfx_timer.stop()
		return

	# Priority 2: In the air.
	if not is_on_floor():
		run_vfx_timer.stop()
		if velocity.y < 0: body.play("jump_ascend")
		else: body.play("jump_descend")
		return

	# Priority 3: On the ground movement.
	var dir = InputComponent.get_input_vector().x
	if dir != 0:
		body.flip_h = (dir < 0)
		body.play("run")
		if run_vfx_timer.is_stopped():
			run_vfx_timer.start()
	else:
		body.play("idle")
		run_vfx_timer.stop()

#jump arc stuff
func calculate_jump_speed(height: float, time_to_peak: float) -> float:
	return (-2.0 * height) / time_to_peak

func calculate_jump_gravity(height: float, time_to_peak: float) -> float:
	return (2.0 * height) / pow(time_to_peak, 2.0)

func calculate_fall_gravity(height: float, time_to_descent: float) -> float:
	return (2.0 * height) / pow(time_to_descent, 2.0)

func calculate_jump_horizontal_speed(distance: float, time_to_peak: float, time_to_descent: float) -> float:
	return distance / (time_to_peak + time_to_descent)

func _on_run_vfx_timer_timeout() -> void:
	var puff_pos = global_position + Vector2(0, 16)
	var puff_rotation = 0 if velocity.x > 0 else 180
	var params = {"rotation_degrees": puff_rotation}
	VFXManager.spawn_vfx("run_puff", puff_pos, params)
