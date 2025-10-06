# Gameplay/Objects/Player/player.gd
extends CharacterBody2D
class_name Player

# --- Player State ---
enum State {NORMAL, DODGING}
var _state: State = State.NORMAL

# --- CONTROL SCHEMES ---
enum AimMode {MOUSE, DPAD}
@export var aim_mode: AimMode = AimMode.DPAD
var dpad_aim_angle: float = 0.0

# --- Movement Variables ---
var speed: float = 200.0

# --- Tilt Variables ---
@export var run_tilt_angle: float = 8.0
@export var tilt_speed: float = 0.2

# --- Dodge/Roll Variables ---
@export_group("Dodging")
@export var dodge_speed: float = 300.0
@export var dodge_duration: float = 0.4
@export var dodge_cooldown: float = 0.8
## The height of the collision capsule during a dodge.
@export var dodge_shape_height: float = 20.0
## The vertical position of the collision capsule during a dodge.
@export var dodge_shape_position_y: float = 4.0
var _can_dodge: bool = true

# --- MODIFIED: Store original shape properties ---
var _normal_shape_height: float
var _normal_shape_position_y: float
var _normal_hurtbox_position_y: float

# --- Input Buffering ---
@export_group("Input Buffering")
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
@onready var jump_speed: float = calculate_jump_speed(jump_height, jump_time_to_peak)

@export_group("Weapon Switching")
@export var ranged_weapon_config: WeaponConfig
@export var melee_weapon_config: WeaponConfig

var current_weapon_config: WeaponConfig
var is_melee_equipped: bool = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var friction = 0.12
var acceleration = 0.25
var was_on_floor: bool = true
var is_running: bool = false
var run_vfx_timer: Timer

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

# --- MODIFIED: Simplified node references ---
@onready var dodge_timer: Timer = %DodgeTimer
@onready var dodge_cooldown_timer: Timer = %DodgeCooldownTimer
@onready var roll_sprite: Sprite2D = %RollSprite
@onready var collision_shape: CollisionShape2D = %Collider
@onready var hurtbox_shape: CollisionShape2D = %HurtboxCollider

@onready var health: HealthComponent = %HealthComponent

const HEAD_FRAME_STRAIT = 16
const HEAD_FRAME_UP = 24
const HEAD_FRAME_DOWN = 8
const HEAD_FRAME_STRAIT_SIDE = 17
const HEAD_FRAME_UP_SIDE = 25
const HEAD_FRAME_DOWN_SIDE = 9

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

	dodge_timer.wait_time = dodge_duration
	dodge_cooldown_timer.wait_time = dodge_cooldown
	dodge_timer.one_shot = true
	dodge_cooldown_timer.one_shot = true
	dodge_timer.timeout.connect(_on_dodge_finished)
	dodge_cooldown_timer.timeout.connect(func(): _can_dodge = true)
	
	# --- NEW: Store the original shape properties on ready ---
	_normal_shape_height = collision_shape.shape.height
	_normal_shape_position_y = collision_shape.position.y
	_normal_hurtbox_position_y = hurtbox_shape.position.y

func _process(_delta: float) -> void:
	if _state == State.DODGING:
		return

	if aim_mode == AimMode.MOUSE:
		handle_mouse_aiming_and_head()
	else:
		handle_dpad_aiming_and_head()

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

	match _state:
		State.NORMAL:
			_state_normal_physics(delta)
		State.DODGING:
			_state_dodging_physics(delta)

	move_and_slide()

	if is_on_floor():
		coyote_timer.stop()
	elif was_on_floor and not is_on_floor():
		coyote_timer.start()

	if _state == State.NORMAL:
		_update_body_animation()
	was_on_floor = is_on_floor()

func _state_normal_physics(_delta: float):
	var dir := InputComponent.get_input_vector().x
	handle_horizontal_movement(dir)

	var can_jump = is_on_floor() or not coyote_timer.is_stopped()
	if Input.is_action_just_pressed("JUMP"):
		if can_jump:
			squash_body.start()
			_execute_jump()
			coyote_timer.stop()
			jump_buffer_timer.stop()
		else:
			jump_buffer_timer.start()

	if is_on_floor() and not jump_buffer_timer.is_stopped():
		squash_body.start()
		_execute_jump()
		jump_buffer_timer.stop()
	
	if Input.is_action_just_pressed("DODGE") and _can_dodge:
		_start_dodge()
		return

	if Input.is_action_just_pressed("SWITCH_WEAPON"):
		_switch_weapon()

	if Input.is_action_pressed("SHOOT"):
		just_shot = true
		var spawn_position = muzzle.global_position
		var target_position: Vector2
		if aim_mode == AimMode.MOUSE:
			target_position = get_global_mouse_position()
		else:
			target_position = weapon_pivot.global_position + (weapon_pivot.transform.x * 1000)
		weapon_component.attack(spawn_position, target_position)
	if Input.is_action_just_released("SHOOT"):
		just_shot = false

	if Input.is_action_just_released("JUMP") and velocity.y < 0:
		velocity.y = max(velocity.y, min_jump_velocity)

func _state_dodging_physics(_delta: float):
	pass

# --- MODIFIED: Dodge State Functions ---

func _start_dodge():
	_state = State.DODGING
	_can_dodge = false
	dodge_timer.start()
	dodge_cooldown_timer.start()

	var dodge_direction = -1.0 if body.flip_h else 1.0
	velocity.x = dodge_direction * dodge_speed
	velocity.y = velocity.y

	visuals.hide()
	weapon_sprite.hide() # <-- ADD THIS LINE
	roll_sprite.show()
	
	# --- MODIFIED: Alter shape properties directly ---
	collision_shape.shape.height = dodge_shape_height
	collision_shape.position.y = dodge_shape_position_y
	hurtbox_shape.shape.height = dodge_shape_height
	hurtbox_shape.position.y = dodge_shape_position_y
	
	var roll_tween = create_tween().set_loops()
	roll_tween.tween_property(roll_sprite, "rotation_degrees", 360 * dodge_direction, dodge_duration).from(0)

func _on_dodge_finished():
	_state = State.NORMAL
	velocity.x = 0

	squash_body.start()
	
	visuals.show()
	weapon_sprite.show() # <-- ADD THIS LINE
	roll_sprite.hide()
	
	# --- MODIFIED: Restore original shape properties ---
	collision_shape.shape.height = _normal_shape_height
	collision_shape.position.y = _normal_shape_position_y
	hurtbox_shape.shape.height = _normal_shape_height
	hurtbox_shape.position.y = _normal_hurtbox_position_y

func handle_mouse_aiming_and_head(): # ... no changes
	var angle_to_mouse = (get_global_mouse_position() - weapon_pivot.global_position).angle()
	weapon_pivot.rotation = angle_to_mouse

	should_flip = get_global_mouse_position().x < self.global_position.x
	
	head.flip_h = should_flip
	body.flip_h = should_flip
	_switch_shoulders(should_flip)

	weapon_pivot.position.x = 6 if should_flip else -6

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
		
func handle_dpad_aiming_and_head(): # ... no changes
	var aim_input := Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")

	if aim_input != Vector2.ZERO:
		var angle = aim_input.angle()
		dpad_aim_angle = snapped(angle, PI / 4.0)
	else:
		dpad_aim_angle = PI if body.flip_h else 0.0

	weapon_pivot.rotation = dpad_aim_angle

	var weapon_should_flip = (dpad_aim_angle > PI / 2.0 or dpad_aim_angle < -PI / 2.0)

	if weapon_should_flip:
		weapon_pivot.scale.y = -1
	else:
		weapon_pivot.scale.y = 1

	head.flip_h = weapon_should_flip
	body.flip_h = weapon_should_flip
	_switch_shoulders(weapon_should_flip)
	
	weapon_pivot.position.x = 6 if weapon_should_flip else -6

	var angle_deg_for_head = rad_to_deg(dpad_aim_angle)

	if weapon_should_flip:
		angle_deg_for_head = 180 - angle_deg_for_head
		if angle_deg_for_head > 180: angle_deg_for_head -= 360

	if angle_deg_for_head > -25 and angle_deg_for_head < 25:
		head.frame = HEAD_FRAME_STRAIT_SIDE
	elif angle_deg_for_head >= 25 and angle_deg_for_head < 65:
		head.frame = HEAD_FRAME_DOWN_SIDE
	elif angle_deg_for_head <= -25 and angle_deg_for_head > -65:
		head.frame = HEAD_FRAME_UP_SIDE
	elif angle_deg_for_head >= 65:
		head.frame = HEAD_FRAME_DOWN
	elif angle_deg_for_head <= -65:
		head.frame = HEAD_FRAME_UP

func on_health_change(old: int, new: int): # ... no changes
	print("Health changed : %s -> %s" % [old, new])

func handle_horizontal_movement(dir: float): # ... no changes
	if dir != 0:
		velocity.x = lerp(velocity.x, dir * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction)

func _execute_jump(): # ... no changes
	body.play("takeoff")
	VFXManager.spawn_vfx("takeoff", global_position + Vector2(0, 15))
	
	velocity.y = jump_velocity
	
	var dir = InputComponent.get_input_vector().x
	if dir != 0:
		velocity.x = dir * horizontal_speed

func _switch_shoulders(switch: bool): # ... no changes
	if switch:
		left_shoulder.z_index = -10
		right_shoulder.z_index = 10
	else:
		left_shoulder.z_index = 10
		right_shoulder.z_index = -10

func _update_body_animation(): # ... no changes
	var just_landed = is_on_floor() and not was_on_floor

	if just_landed:
		body.play("land")
		squash_body.start(Vector2(1.3, 0.7))
		var landing_pos := global_position + Vector2(0, 16)
		VFXManager.spawn_vfx("land", landing_pos)
		Globals.camera_shake_requested.emit(2.0)
		return

	if body.is_playing() and body.animation in ["takeoff", "land"]:
		if is_running:
			is_running = false
			run_vfx_timer.stop()
		return

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

	var dir = InputComponent.get_input_vector().x
	var target_tilt_deg = 0.0

	if dir != 0:
		body.play("run")
		if not is_running:
			is_running = true
			_spawn_run_puff()
			run_vfx_timer.start()
			target_tilt_deg = - run_tilt_angle if body.flip_h else run_tilt_angle
	else:
		body.play("idle")
		if is_running:
			is_running = false
			run_vfx_timer.stop()
		target_tilt_deg = 0.0

	if just_shot:
		bobber_head.stop()
		bobber_shoulders.stop()
	else:
		if is_running:
			bobber_head.start(Vector2(0, 1), Bobber.MotionType.ELLIPSE, 2.0)
			bobber_shoulders.start(Vector2(2, 1), Bobber.MotionType.FIGURE_EIGHT, 1.0)
			bobber_weapon.start(Vector2(1.5, 1.5), Bobber.MotionType.FIGURE_EIGHT, 1.0)
		else:
			bobber_head.start(Vector2(0, 0.3), Bobber.MotionType.ELLIPSE, 0.5)
			bobber_shoulders.start(Vector2(0, 0.8), Bobber.MotionType.FIGURE_EIGHT, 0.5)
			bobber_weapon.start(Vector2(0, 1.5), Bobber.MotionType.FIGURE_EIGHT, 0.5)

	if not is_equal_approx(visuals.rotation_degrees, target_tilt_deg):
		if tilt_tween and tilt_tween.is_running():
			tilt_tween.kill()
		tilt_tween = create_tween()
		tilt_tween.tween_property(visuals, "rotation_degrees", target_tilt_deg, tilt_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func calculate_jump_speed(height: float, time_to_peak: float): # ... no changes
	return (-2.0 * height) / time_to_peak

func calculate_jump_gravity(height: float, time_to_peak: float): # ... no changes
	return (2.0 * height) / pow(time_to_peak, 2.0)

func calculate_fall_gravity(height: float, time_to_descent: float): # ... no changes
	return (2.0 * height) / pow(time_to_descent, 2.0)

func calculate_jump_horizontal_speed(distance: float, time_to_peak: float, time_to_descent: float): # ... no changes
	return distance / (time_to_peak + time_to_descent)

func _spawn_run_puff(): # ... no changes
	var puff_pos = global_position + Vector2(0, 16)
	var puff_scale = Vector2(-1, 1) if velocity.x > 0 else Vector2(1, 1)
	var params = {"scale": puff_scale}
	VFXManager.spawn_vfx("run_puff", puff_pos, params)

func _on_run_vfx_timer_timeout(): # ... no changes
	_spawn_run_puff()

func _on_recoil_shot(direction: Vector2): # ... no changes
	squash_gun.start(Vector2(0.4, 1.3))
	Globals.camera_shake_requested.emit(5.0)
	_apply_recoil_body()

	if current_weapon_config and current_weapon_config.attack_data.attach_to == AttackData.AttachTarget.OWNER:
		_apply_melee_swing_animation()
	else:
		var rot := rad_to_deg(direction.angle())
		var params = {"rotation_degrees": rot}
		VFXManager.spawn_vfx("gun_blast", muzzle.global_position, params, self)
		_apply_recoil_gun(direction)

func _apply_recoil_body(): # ... no changes
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

func _apply_recoil_gun(shoot_direction: Vector2): # ... no changes
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

func _apply_melee_swing_animation(): # ... no changes
	var tween = create_tween()
	var original_pos = Vector2(8, 0)
	var swing_pos = Vector2(original_pos.x + 20.0, original_pos.y)
	
	var swing_duration = current_weapon_config.attack_data.duration if current_weapon_config else 0.3
	var forward_time = swing_duration * 0.3
	var return_time = swing_duration * 0.7

	tween.tween_property(weapon_sprite, "position", swing_pos, forward_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_sprite, "position", original_pos, return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _switch_weapon(): # ... no changes
	is_melee_equipped = not is_melee_equipped
	if is_melee_equipped:
		current_weapon_config = melee_weapon_config
	else:
		current_weapon_config = ranged_weapon_config
	_update_weapon_display()

func _update_weapon_display(): # ... no changes
	if not current_weapon_config:
		printerr("Player is missing a weapon configuration!")
		return
	
	weapon_component.base_attack_data = current_weapon_config.attack_data
	weapon_sprite.texture = current_weapon_config.weapon_texture

func _unhandled_input(event: InputEvent): # ... no changes
	if event.is_action_pressed("TOGGLE_AIM_MODE"):
		if aim_mode == AimMode.MOUSE:
			aim_mode = AimMode.DPAD
			print("Switched to D-Pad aiming")
		else:
			aim_mode = AimMode.MOUSE
			print("Switched to Mouse aiming")
		get_viewport().set_input_as_handled()