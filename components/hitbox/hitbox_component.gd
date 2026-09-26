class_name HitboxComponent
extends Area2D

signal hit_confirmed(target: Node, damage: int)

@export var damage: int = 10
@export var offset_distance: float = 12.0
@export var debug_visible: bool = true

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var debug_shape: Polygon2D = $DebugShape

var _active: bool = false
var _hit_targets: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_active(false)

func set_facing(facing: StringName) -> void:
	match facing:
		&"up":
			position = Vector2(0.0, -offset_distance)
		&"down":
			position = Vector2(0.0, offset_distance)
		&"left":
			position = Vector2(-offset_distance, 0.0)
		&"right":
			position = Vector2(offset_distance, 0.0)

func set_active(active: bool) -> void:
	if _active == active:
		return

	_active = active
	debug_shape.visible = active and debug_visible
	collision_shape.set_deferred("disabled", not active)

	if active:
		_hit_targets.clear()

func is_active() -> bool:
	return _active

func _on_body_entered(body: Node2D) -> void:
	_try_apply_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_try_apply_hit(area)

func _try_apply_hit(target: Node) -> void:
	if not _active or target == null:
		return

	var receiver := target
	if not receiver.has_method("receive_hit") and target.get_parent() != null:
		receiver = target.get_parent()

	if not receiver.has_method("receive_hit"):
		return

	var receiver_id := receiver.get_instance_id()
	if _hit_targets.has(receiver_id):
		return

	_hit_targets[receiver_id] = true
	receiver.call("receive_hit", damage, global_position)
	hit_confirmed.emit(receiver, damage)
