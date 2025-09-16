extends CharacterBody2D

var oscillator_spring = 50.0
var oscillator_damp = 10.0
var oscillator_velocity = 5.0

@export var friction: float = 0.1

@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var body: Sprite2D = %Body
@onready var head: Sprite2D = %Head
@onready var hit_flash: HitFlash = %HitFlash

func _ready() -> void:
	hurtbox.hit_recieved.connect(_on_hit_recived)

func _physics_process(_delta):
	# Apply friction to slow down over time
	velocity.x = lerp(velocity.x, 0.0, friction)
	move_and_slide()

func _on_hit_recived(data: AttackData, direction: Vector2):
	hit_flash.flash()
	
	var directional_osc_velocity = abs(oscillator_velocity) * sign(direction.x)
	
	# 2. Add a fallback for perfectly vertical hits (where direction.x would be 0)
	if directional_osc_velocity == 0:
		directional_osc_velocity = oscillator_velocity # Default to the base value

	if direction != Vector2.ZERO:
		velocity.x = direction.x * data.knockback_strength

	#var rot := rad_to_deg(direction.angle())
	#VFXManager.spawn_vfx("land", position, {"rotation_degrees": rot - 90})

	DampedOscillator.animate(body, "rotation_degrees", oscillator_spring, oscillator_damp, directional_osc_velocity, 100.0)
	DampedOscillator.animate(head, "rotation_degrees", oscillator_spring, oscillator_damp, -directional_osc_velocity, 100.0)
