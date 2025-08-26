# Gameplay/Objects/Player/player.gd
# Gameplay/Objects/Player/player.gd
extends CharacterBody2D
class_name Player

# --- Movement Variables ---
var speed: float = 200.0

# --- Tilt Variables ---
@export var run_tilt_angle: float = 8.0
@export var tilt_speed: float = 0.2

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

	initial_left_shoulder_pos = left_shoulder.position
	initial_right_shoulder_pos = right_shoulder.position

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

	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		squash_body.start()
		_execute_jump()

	if Input.is_action_pressed("SHOOT"):
		just_shot = true
		var spawn_position = muzzle.global_position
		weapon_component.attack(spawn_position, get_global_mouse_position())

	if Input.is_action_just_released("SHOOT"):
		just_shot = false

	move_and_slide()

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

func _execute_jump() -> void:
	set_physics_process(false)
	body.play("takeoff")
	VFXManager.spawn_vfx("takeoff", global_position + Vector2(0, 15))
	await body.animation_finished
	velocity.y = jump_speed
	var dir = InputComponent.get_input_vector().x
	velocity.x = sign(dir) * horizontal_speed
	set_physics_process(true)

func _switch_shoulders(switch: bool) -> void:
	if switch:
		left_shoulder.z_index = -10
		right_shoulder.z_index = 10
	else:
		left_shoulder.z_index = 10
		right_shoulder.z_index = -10

# --- FINAL RESTRUCTURED Animation Logic ---
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

	# FIX: This block sets the PRIMARY animation based on movement input.
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

	# FIX: This block MODIFIES the secondary animation (bobbing) based on shooting state.
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

	# NEW: Smoothly tween the visuals to the target tilt.
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
	var shoot_direction = weapon_pivot.global_transform.x.normalized()

	var rot := rad_to_deg(muzzle.global_position.angle_to(shoot_direction))
	var blast_scale = Vector2(1, -1)
	var params = {"rotation_degrees": rot, "scale": blast_scale}
	VFXManager.spawn_vfx("takeoff", muzzle.global_position, params)

	Globals.camera_shake_requested.emit(5.0)
	_apply_recoil_gun(direction)
	_apply_recoil_body()

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
