extends Area2D
class_name HurtboxComponent

@export var health_component: HealthComponent
@export var hit_cooldown: float = 0.5
@export var cooldown_enabled: bool = false

@onready var hit_timer := Timer.new()

signal hit_recieved(data: AttackData, direction: Vector2)

func _ready() -> void:
	add_child(hit_timer)
	hit_timer.one_shot = true
	hit_timer.wait_time = hit_cooldown

	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not area is HitboxComponent:
		return

	var hitbox: HitboxComponent = area
	# This part is a fallback for non-bullet attacks that don't provide a direction.
	var direction_to_hitbox = (hitbox.global_position - global_position).normalized()
	recieve_attack_data(hitbox.data, direction_to_hitbox)

#recive damage directly witout hitbox (mainly for raycasts)
func recieve_attack_data(data: AttackData, direction: Vector2 = Vector2.ZERO):
	if cooldown_enabled and not hit_timer.is_stopped():
		print("on hit cooldown")
		return

	hit_recieved.emit(data, direction)
	if health_component:
		health_component.take_damage(data)

	if cooldown_enabled:
		hit_timer.start()
