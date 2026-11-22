class_name HitboxComponent
extends Area2D

signal hit_confirmed(target: Node, damage: int)

@export var damage: int = 10
@export var offset_distance: float = 12.0
@export var debug_visible: bool = false
# Extra size for wide weapon swings, expressed for a side (left/right) swing:
# x = reach, y = arc height. Up/down facings swap the axes.
var shape_scale: Vector2 = Vector2.ONE

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var debug_shape: Polygon2D = $DebugShape

var _active: bool = false
var _hit_targets: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_active(false)

func set_facing(facing: StringName) -> void:
	var vertical := facing == &"up" or facing == &"down"
	var applied := Vector2(shape_scale.y, shape_scale.x) if vertical else shape_scale
	collision_shape.scale = applied
	debug_shape.scale = applied
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

func _physics_process(_delta: float) -> void:
	if not _active:
		return
	# Existing overlaps do not necessarily emit area_entered on activation.
	for area in get_overlapping_areas():
		_try_apply_hit(area)

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

	var result: Variant = receiver.call(
		"receive_hit",
		damage,
		global_position
	)
	var applied_damage: int = int(result)

	if applied_damage <= 0:
		return

	_hit_targets[receiver_id] = true
	hit_confirmed.emit(receiver, applied_damage)
