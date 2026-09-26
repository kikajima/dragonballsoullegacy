class_name KiBlastProjectile
extends Area2D

@export var speed: float = 210.0
@export var damage: int = 12
@export var lifetime: float = 1.6

var _direction: Vector2 = Vector2.RIGHT
var _lifetime_left: float

func _ready() -> void:
	_lifetime_left = lifetime
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(direction: Vector2) -> void:
	if direction.is_zero_approx():
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()

	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area == null or not area.has_method("receive_hit"):
		return

	area.call("receive_hit", damage, global_position)
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == null or not body is CollisionObject2D:
		return

	var collision_body := body as CollisionObject2D
	if collision_body.collision_layer & 1 != 0:
		queue_free()
