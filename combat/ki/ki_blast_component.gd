class_name KiBlastComponent
extends Node

signal cast_started(facing: StringName)
signal projectile_fired
signal cast_finished
signal cast_buffered(buffered_count: int)

@export var projectile_scene: PackedScene
@export var ki_component_path: NodePath
@export var ki_cost: float = 12.0
@export var cast_duration: float = 0.32
@export var fire_at: float = 0.12
@export var chain_from: float = 0.24
@export_range(1, 8, 1)
var max_buffered_casts: int = 4
@export var spawn_distance: float = 18.0

@onready var ki_component: KiComponent = get_node(ki_component_path) as KiComponent

var _casting: bool = false
var _elapsed: float = 0.0
var _fired: bool = false
var _cast_facing: StringName = &"down"

var _buffered_facings: Array[StringName] = []

func start_cast(facing: StringName) -> bool:
	if _casting:
		return false

	return _begin_cast(facing)

func buffer_cast(facing: StringName) -> bool:
	if not _casting:
		return start_cast(facing)

	if projectile_scene == null or ki_component == null:
		return false

	if _buffered_facings.size() >= max_buffered_casts:
		return false

	var reserved_cost := ki_cost * float(_buffered_facings.size() + 1)
	if not ki_component.can_consume(reserved_cost):
		return false

	_buffered_facings.append(facing)
	cast_buffered.emit(_buffered_facings.size())

	if _elapsed >= chain_from:
		_consume_next_buffered_cast()

	return true

func tick_cast(caster: Node2D, delta: float) -> void:
	if not _casting:
		return

	_elapsed += delta

	if not _fired and _elapsed >= fire_at:
		_fire(caster)

	if not _buffered_facings.is_empty() and _elapsed >= chain_from:
		_consume_next_buffered_cast()
		return

	if _elapsed >= cast_duration:
		_finish_cast()

func cancel_cast() -> void:
	if not _casting:
		return

	_buffered_facings.clear()
	_finish_cast()

func is_casting() -> bool:
	return _casting

func get_cast_facing() -> StringName:
	return _cast_facing

func get_buffered_cast_count() -> int:
	return _buffered_facings.size()

func _begin_cast(facing: StringName) -> bool:
	if projectile_scene == null or ki_component == null:
		return false

	if not ki_component.consume(ki_cost):
		return false

	_casting = true
	_elapsed = 0.0
	_fired = false
	_cast_facing = facing
	cast_started.emit(_cast_facing)
	return true

func _consume_next_buffered_cast() -> void:
	if _buffered_facings.is_empty():
		return

	var next_facing := _buffered_facings.pop_front()

	if not _begin_cast(next_facing):
		_buffered_facings.clear()
		_finish_cast()

func _fire(caster: Node2D) -> void:
	_fired = true

	var projectile := projectile_scene.instantiate() as KiBlastProjectile
	if projectile == null:
		return

	var direction := _facing_vector(_cast_facing)
	var parent := caster.get_tree().current_scene

	if parent == null:
		parent = caster.get_parent()

	parent.add_child(projectile)
	projectile.global_position = caster.global_position + direction * spawn_distance
	projectile.setup(direction)
	projectile_fired.emit()

func _finish_cast() -> void:
	_casting = false
	_elapsed = 0.0
	_fired = false
	cast_finished.emit()

func _facing_vector(facing: StringName) -> Vector2:
	match facing:
		&"up":
			return Vector2.UP
		&"down":
			return Vector2.DOWN
		&"left":
			return Vector2.LEFT
		&"right":
			return Vector2.RIGHT

	return Vector2.DOWN
