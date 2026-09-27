class_name KiBlastComponent
extends Node

signal cast_started(facing: StringName)
signal projectile_fired(facing: StringName, variant: int)
signal cast_finished
signal cast_buffered(buffered_count: int)

@export var projectile_scene: PackedScene
@export var ki_component_path: NodePath
@export var ki_cost: float = 12.0

# A referência do jogo original mostra uma preparação curta antes do
# primeiro disparo e, depois, alternância direta entre os braços.
@export var startup_duration: float = 0.22
@export var repeat_interval: float = 0.40

@export_range(1, 8, 1)
var max_buffered_casts: int = 4

@export var spawn_distance: float = 18.0

@onready var ki_component: KiComponent = get_node(ki_component_path) as KiComponent

var _casting: bool = false
var _before_first_shot: bool = false
var _time_until_shot: float = 0.0

var _cast_facing: StringName = &"down"
var _current_variant: int = 0
var _visual_state: StringName = &"ki_blast_prepare"

var _buffered_facings: Array[StringName] = []

func start_cast(facing: StringName) -> bool:
	if _casting:
		return false

	if projectile_scene == null or ki_component == null:
		return false

	if not ki_component.can_consume(ki_cost):
		return false

	_casting = true
	_before_first_shot = true
	_time_until_shot = startup_duration
	_cast_facing = facing
	_current_variant = 0
	_visual_state = &"ki_blast_prepare"
	_buffered_facings.clear()

	cast_started.emit(_cast_facing)
	return true

func buffer_cast(facing: StringName) -> bool:
	if not _casting:
		return start_cast(facing)

	if projectile_scene == null or ki_component == null:
		return false

	if _buffered_facings.size() >= max_buffered_casts:
		return false

	if not ki_component.can_consume(ki_cost):
		return false

	_buffered_facings.append(facing)
	cast_buffered.emit(_buffered_facings.size())
	return true

func tick_cast(
	caster: Node2D,
	delta: float,
	trigger_held: bool,
	desired_facing: StringName
) -> void:
	if not _casting:
		return

	_time_until_shot -= delta

	if _before_first_shot:
		if _time_until_shot > 0.0:
			return

		if not _fire(caster, _cast_facing):
			_finish_cast()
			return

		_before_first_shot = false
		_time_until_shot = repeat_interval
		return

	if _time_until_shot > 0.0:
		return

	var next_facing: StringName

	if not _buffered_facings.is_empty():
		next_facing = _buffered_facings[0]
		_buffered_facings.remove_at(0)
	elif trigger_held:
		next_facing = desired_facing
	else:
		_finish_cast()
		return

	if not _fire(caster, next_facing):
		_buffered_facings.clear()
		_finish_cast()
		return

	_time_until_shot += repeat_interval

func cancel_cast() -> void:
	if not _casting:
		return

	_buffered_facings.clear()
	_finish_cast()

func is_casting() -> bool:
	return _casting

func get_cast_facing() -> StringName:
	return _cast_facing

func get_cast_variant() -> int:
	return _current_variant

func get_cast_state() -> StringName:
	return _visual_state

func get_buffered_cast_count() -> int:
	return _buffered_facings.size()

func _fire(caster: Node2D, facing: StringName) -> bool:
	if projectile_scene == null or ki_component == null:
		return false

	if not ki_component.consume(ki_cost):
		return false

	_current_variant = 2 if _current_variant == 1 else 1
	_cast_facing = facing
	_visual_state = StringName("ki_blast_%d" % _current_variant)

	var projectile := projectile_scene.instantiate() as KiBlastProjectile
	if projectile == null:
		return false

	var direction := _facing_vector(_cast_facing)
	var parent := caster.get_tree().current_scene

	if parent == null:
		parent = caster.get_parent()

	parent.add_child(projectile)
	projectile.global_position = caster.global_position + direction * spawn_distance
	projectile.setup(direction)

	projectile_fired.emit(_cast_facing, _current_variant)
	return true

func _finish_cast() -> void:
	_casting = false
	_before_first_shot = false
	_time_until_shot = 0.0
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
