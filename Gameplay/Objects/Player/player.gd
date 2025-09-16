# Gameplay/Objects/Player/player.gd
# Gameplay/Objects/Player/player.gd
extends CharacterBody2D
class_name Player

# --- Movement Variables ---
var speed: float = 200.0

# --- Tilt Variables ---
@export var run_tilt_angle: float = 8.0
@export var tilt_speed: float = 0.2

# --- Input Buffering ---
@export_group("Input Buffering")
## How long (in seconds) the game remembers a jump input before the player lands.
@export var jump_buffer_duration: float = 0.15

@onready var jump_buffer_timer: Timer = %JumpTimerBuffer

@export var coyote_time_duration: float = 0.12

@onready var coyote_timer: Timer = %CoyoteTimer

# --- Jump Variables ---
@export_group("Jumping")
@export var max_jump_height: float = 100.0
@export var min_jump_height: float = 40.0
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_descent: float = 0.5

# --- Calculated Jump Physics ---
@onready var jump_velocity: float = (-2.0 * max_jump_height) / jump_time_to_peak
@onready var min_jump_velocity: float = (-2.0 * min_jump_height) / jump_time_to_peak
@onready var up_gravity: float = (2.0 * max_jump_height) / pow(jump_time_to_peak, 2.0)
@onready var fall_gravity: float = (2.0 * max_jump_height) / pow(jump_time_to_descent, 2.0)
@onready var horizontal_speed: float = 120.0 / (jump_time_to_peak + jump_time_to_descent)

@export var jump_height := 100.0

@export var jump_distance := 120.0
@onready var jump_speed := calculate_jump_speed(jump_height, jump_time_to_peak)

@export_group("Weapon Switching")
@export var ranged_weapon_config: WeaponConfig
@export var melee_weapon_config: WeaponConfig

var current_weapon_config: WeaponConfig
var is_melee_equipped: bool = false

var bullet = preload("res://Gameplay/Objects/Bullet/bullet.tscn")

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var friction = 0.12
var acceleration = 0.25

var was_on_floor: bool = true
var is_running: bool = false

var run_vfx_timer: Timer

# Get references to the new nodes in the scene tree.
@onready var body: AnimatedSprite2D = %Body
@onready var head: Sprite2D = %Head
@onready var weapon_pivot: Node2D = %WeaponPivot
@onready var muzzle: Marker2D = %Muzzle
@onready var weapon_sprite: Sprite2D = %WeaponSprite
@onready var squash_body: Squasher = %SquasherBody
@onready var squash_gun: Squasher = %SquasherGun
@onready var left_shoulder: Sprite2D = %LeftShoulder
@onready var right_shoulder: Sprite2D = %RightShoulder
@onready var bobber_head: Node = %BobberHead
@onready var bobber_shoulders: Node = %BobberShoulders
@onready var bobber_weapon: Node = %BobberWeapon
@onready var weapon_component: WeaponComponent = %WeaponSystem
@onready var visuals: Node2D = %Visuals

@onready var health: HealthComponent = %HealthComponent

# Define constants for the head frames to make the code clearer.
const HEAD_FRAME_STRAIT = 16
const HEAD_FRAME_UP = 24
const HEAD_FRAME_DOWN = 8
const HEAD_FRAME_STRAIT_SIDE = 17
const HEAD_FRAME_UP_SIDE = 25
const HEAD_FRAME_DOWN_SIDE = 9

# --- RECOIL VARIABLES ---
const GUN_RECOIL_DISTANCE: float = -3.0
const BODY_RECOIL_STRENGTH: float = 10.0

var just_shot: bool = false
var should_flip: bool = false
var shot_cooldown_timer: Timer
var recoil_tween: Tween
var tilt_tween: Tween

var initial_left_shoulder_pos: Vector2
var initial_right_shoulder_pos: Vector2

func _ready() -> void:
	health.health_changed.connect(on_health_change)
	add_to_group("player")

	run_vfx_timer = Timer.new()
	run_vfx_timer.wait_time = 0.5
	run_vfx_timer.timeout.connect(_on_run_vfx_timer_timeout)
	add_child(run_vfx_timer)

	jump_buffer_timer.wait_time = jump_buffer_duration
	coyote_timer.wait_time = coyote_time_duration

	initial_left_shoulder_pos = left_shoulder.position
	initial_right_shoulder_pos = right_shoulder.position

	current_weapon_config = ranged_weapon_config
	_update_weapon_display()

	weapon_component.recoil_shot.connect(_on_recoil_shot)

func _process(_delta: float) -> void:
	handle_aiming_and_head()

func _physics_process(delta: float) -> void:
	if DungeonManager.current_state != DungeonManager.State.IDLE:
		velocity = Vector2.ZERO
		body.play("idle")
		return

	if not is_on_floor():
		if velocity.y <= 0.0:
			velocity.y += up_gravity * delta
		else:
			velocity.y += fall_gravity * delta

	var dir := InputComponent.get_input_vector().x
	handle_horizontal_movement(dir)

	# --- NEW: JUMP INPUT with Coyote Time and Buffering ---
	var can_jump = is_on_floor() or not coyote_timer.is_stopped()

	if Input.is_action_just_pressed("JUMP"):
		if can_jump:
			# If we are on the floor or coyote time is active, jump.
			squash_body.start()
			_execute_jump()
			# Consume both coyote time and any active buffer to prevent conflicts.
			coyote_timer.stop()
			jump_buffer_timer.stop()
		else:
			# If we can't jump, buffer the input.
			jump_buffer_timer.start()

	# --- Check for and Execute a Buffered Jump ---
	# This check happens every physics frame.
	if is_on_floor() and not jump_buffer_timer.is_stopped():
		# If we've just landed and the buffer is active, execute a jump.
		squash_body.start()
		_execute_jump()
		# Consume the buffer by stopping the timer.
		jump_buffer_timer.stop()
	
	if Input.is_action_just_pressed("SWITCH_WEAPON"):
		_switch_weapon()

	if Input.is_action_pressed("SHOOT"):
		just_shot = true
		var spawn_position = muzzle.global_position
		weapon_component.attack(spawn_position, get_global_mouse_position())

	if Input.is_action_just_released("SHOOT"):
		just_shot = false

	# --- NEW: Variable Jump Height Logic ---
	# If the jump button is released while the player is moving up...
	if Input.is_action_just_released("JUMP") and velocity.y < 0:
		# ...cut their upward velocity to the minimum jump speed.
		# Using max() ensures we don't accidentally increase their speed if they are already falling.
		velocity.y = max(velocity.y, min_jump_velocity)

	move_and_slide()

	# ---Coyote Timer Management ---
	if is_on_floor():
		# If we are on the ground, the coyote timer should always be stopped.
		coyote_timer.stop()
	elif was_on_floor and not is_on_floor():
		# If we were on the floor last frame but not this one, we just left a ledge.
		# Start the coyote timer to give the player a grace period.
		coyote_timer.start()

	_update_body_animation()
	was_on_floor = is_on_floor()

func handle_aiming_and_head() -> void:
	var angle_to_mouse = (get_global_mouse_position() - weapon_pivot.global_position).angle()
	weapon_pivot.rotation = angle_to_mouse

	should_flip = get_global_mouse_position().x < self.global_position.x
	head.flip_h = should_flip

	if should_flip:
		weapon_pivot.scale.y = -1
	else:
		weapon_pivot.scale.y = 1

	var angle_deg = rad_to_deg(angle_to_mouse)

	if should_flip:
		angle_deg = 180 - angle_deg
		if angle_deg > 180: angle_deg -= 360

	if angle_deg > -25 and angle_deg < 25:
		head.frame = HEAD_FRAME_STRAIT_SIDE
	elif angle_deg >= 25 and angle_deg < 65:
		head.frame = HEAD_FRAME_DOWN_SIDE
	elif angle_deg <= -25 and angle_deg > -65:
		head.frame = HEAD_FRAME_UP_SIDE
	elif angle_deg >= 65:
		head.frame = HEAD_FRAME_DOWN
	elif angle_deg <= -65:
		head.frame = HEAD_FRAME_UP

func on_health_change(old: int, new: int) -> void:
	print("Health changed : %s -> %s" % [old, new])

func handle_horizontal_movement(dir: float) -> void:
	if dir != 0:
		velocity.x = lerp(velocity.x, dir * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction)

func _execute_jump() -> void:
	# The takeoff animation should play, but it must not block the physics.
	body.play("takeoff")
	VFXManager.spawn_vfx("takeoff", global_position + Vector2(0, 15))
	
	# Apply the maximum possible jump velocity instantly.
	velocity.y = jump_velocity
	
	# Horizontal speed can still be applied if desired.
	var dir = InputComponent.get_input_vector().x
	if dir != 0:
		velocity.x = dir * horizontal_speed

func _switch_shoulders(switch: bool) -> void:
	if switch:
		left_shoulder.z_index = -10
		right_shoulder.z_index = 10
	else:
		left_shoulder.z_index = 10
		right_shoulder.z_index = -10

# --- Animation Logic ---
func _update_body_animation() -> void:
	var just_landed = is_on_floor() and not was_on_floor

	# Priority 1: Landing
	if just_landed:
		body.play("land")
		squash_body.start(Vector2(1.3, 0.7))
		var landing_pos := global_position + Vector2(0, 16)
		VFXManager.spawn_vfx("land", landing_pos)
		Globals.camera_shake_requested.emit(2.0)
		return

	# Let one-shot animations finish
	if body.is_playing() and body.animation in ["takeoff", "land"]:
		if is_running:
			is_running = false
			run_vfx_timer.stop()
		return

	# Priority 2: In Air
	if not is_on_floor():
		if is_running:
			is_running = false
			run_vfx_timer.stop()

		bobber_head.stop()
		bobber_shoulders.stop()

		if velocity.y < 0:
			body.play("jump_ascend")
		else:
			body.play("jump_descend")
		return

	# --- ON GROUND LOGIC ---
	var dir = InputComponent.get_input_vector().x
	var target_tilt_deg = 0.0

	# This block sets the PRIMARY animation based on movement input.
	if dir != 0:
		body.flip_h = (dir < 0)
		_switch_shoulders(dir < 0)
		body.play("run")
		if not is_running:
			is_running = true
			_spawn_run_puff()
			run_vfx_timer.start()
			# Set the target tilt angle based on movement direction
			target_tilt_deg = - run_tilt_angle if body.flip_h else run_tilt_angle
	else:
		body.play("idle")
		if is_running:
			is_running = false
			run_vfx_timer.stop()
		# When idle, the target tilt is zero.
		target_tilt_deg = 0.0

	# This block MODIFIES the secondary animation (bobbing) based on shooting state.
	if just_shot:
		bobber_head.stop()
		bobber_shoulders.stop()
	else:
		# Not shooting, so apply normal bobbing based on the state set above.
		if is_running:
			bobber_head.start(Vector2(0, 1), Bobber.MotionType.ELLIPSE, 2.0)
			bobber_shoulders.start(Vector2(2, 1), Bobber.MotionType.FIGURE_EIGHT, 1.0) # Run bob
			bobber_weapon.start(Vector2(1.5, 1.5), Bobber.MotionType.FIGURE_EIGHT, 1.0)
		else:
			bobber_head.start(Vector2(0, 0.3), Bobber.MotionType.ELLIPSE, 0.5)
			bobber_shoulders.start(Vector2(0, 0.8), Bobber.MotionType.FIGURE_EIGHT, 0.5) # Idle bob
			bobber_weapon.start(Vector2(0, 1.5), Bobber.MotionType.FIGURE_EIGHT, 0.5)

	# Smoothly tween the visuals to the target tilt.
	if not is_equal_approx(visuals.rotation_degrees, target_tilt_deg):
		if tilt_tween and tilt_tween.is_running():
			tilt_tween.kill()
		tilt_tween = create_tween()
		tilt_tween.tween_property(visuals, "rotation_degrees", target_tilt_deg, tilt_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

#jump arc stuff
func calculate_jump_speed(height: float, time_to_peak: float) -> float:
	return (-2.0 * height) / time_to_peak

func calculate_jump_gravity(height: float, time_to_peak: float) -> float:
	return (2.0 * height) / pow(time_to_peak, 2.0)

func calculate_fall_gravity(height: float, time_to_descent: float) -> float:
	return (2.0 * height) / pow(time_to_descent, 2.0)

func calculate_jump_horizontal_speed(distance: float, time_to_peak: float, time_to_descent: float) -> float:
	return distance / (time_to_peak + time_to_descent)

func _spawn_run_puff() -> void:
	var puff_pos = global_position + Vector2(0, 16)
	var puff_scale = Vector2(-1, 1) if velocity.x > 0 else Vector2(1, 1)
	var params = {"scale": puff_scale}
	VFXManager.spawn_vfx("run_puff", puff_pos, params)

func _on_run_vfx_timer_timeout() -> void:
	_spawn_run_puff()

func _on_recoil_shot(direction: Vector2) -> void:
	squash_gun.start(Vector2(0.4, 1.3))
	Globals.camera_shake_requested.emit(5.0)
	_apply_recoil_body() # Apply body recoil for both attack types

	# --- MODIFIED: Check current attack type ---
	if current_weapon_config and current_weapon_config.attack_data.attach_to == AttackData.AttachTarget.OWNER:
		# Melee Attack Swing Animation
		_apply_melee_swing_animation()
	else:
		# Ranged Attack Recoil & VFX
		var rot := rad_to_deg(direction.angle())
		var params = {"rotation_degrees": rot}
		VFXManager.spawn_vfx("gun_blast", muzzle.global_position, params, self)
		_apply_recoil_gun(direction)

func _apply_recoil_body() -> void:
	bobber_head.stop()
	bobber_shoulders.stop()

	if recoil_tween and recoil_tween.is_running():
		recoil_tween.kill()

		left_shoulder.position = initial_left_shoulder_pos
		right_shoulder.position = initial_right_shoulder_pos

		recoil_tween = create_tween()

		var shoulder_recoil_offset = GUN_RECOIL_DISTANCE * 0.5
		if should_flip:
			shoulder_recoil_offset *= -1.0

		var recoil_left_pos = initial_left_shoulder_pos + Vector2(shoulder_recoil_offset, 0)
		var recoil_right_pos = initial_right_shoulder_pos + Vector2(shoulder_recoil_offset, 0)

		recoil_tween.tween_property(left_shoulder, "position", recoil_left_pos, 0.05)
		recoil_tween.tween_property(right_shoulder, "position", recoil_right_pos, 0.05)
		recoil_tween.tween_property(left_shoulder, "position", initial_left_shoulder_pos, 0.25)
		recoil_tween.tween_property(right_shoulder, "position", initial_right_shoulder_pos, 0.25)

func _apply_recoil_gun(shoot_direction: Vector2) -> void:
	var recoil_impulse = shoot_direction * BODY_RECOIL_STRENGTH
	if is_on_floor():
		velocity.x -= recoil_impulse.x
	else:
		velocity -= recoil_impulse

	var tween = create_tween()
	var original_pos = Vector2(8, 0)
	var recoil_pos = Vector2(original_pos.x + GUN_RECOIL_DISTANCE, original_pos.y)

	tween.tween_property(weapon_sprite, "position", recoil_pos, 0.05) \
		 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_sprite, "position", original_pos, 0.25) \
		 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- NEW: Melee Swing Animation ---
func _apply_melee_swing_animation() -> void:
	var tween = create_tween()
	var original_pos = Vector2(8, 0) # Default position from the scene
	var swing_pos = Vector2(original_pos.x + 20.0, original_pos.y) # Move forward

	# Use the duration from the melee AttackData to time the animation
	var swing_duration = current_weapon_config.attack_data.duration if current_weapon_config else 0.3
	var forward_time = swing_duration * 0.3 # Quick forward lunge
	var return_time = swing_duration * 0.7 # Slower return to ready

	# Chain tweens for a complete swing animation
	tween.tween_property(weapon_sprite, "position", swing_pos, forward_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_sprite, "position", original_pos, return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- WEAPON SWITCHING ---
func _switch_weapon():
	is_melee_equipped = not is_melee_equipped
	if is_melee_equipped:
		current_weapon_config = melee_weapon_config
	else:
		current_weapon_config = ranged_weapon_config
	_update_weapon_display()

func _update_weapon_display():
	if not current_weapon_config:
		printerr("Player is missing a weapon configuration!")
		return
	
	weapon_component.base_attack_data = current_weapon_config.attack_data
	weapon_sprite.texture = current_weapon_config.weapon_texture
