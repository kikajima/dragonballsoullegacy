class_name SpecialAttackComponent
extends Node

signal selection_changed(
	ability_id: StringName,
	display_name: String,
	index: int
)
signal cast_started(ability_id: StringName)
signal cast_finished(ability_id: StringName)

@export var abilities: Array[SpecialAttackData] = []
@export var projectile_scene: PackedScene
@export var beam_scene: PackedScene
@export var ki_component_path: NodePath
@export var loadout_component_path: NodePath
@export var spawn_distance: float = 20.0

@onready var ki_component: KiComponent = get_node(
	ki_component_path
) as KiComponent

@onready var loadout_component: AbilityLoadoutComponent = get_node(
	loadout_component_path
) as AbilityLoadoutComponent

var _selected_index: int = 0
var _casting: bool = false
var _fired: bool = false
var _startup_left: float = 0.0
var _lock_left: float = 0.0
var _cast_facing: StringName = &"down"
var _cast_direction: Vector2 = Vector2.DOWN
var _active_data: SpecialAttackData

func _ready() -> void:
	for ability in abilities:
		if ability == null or ability.ability_id == &"":
			continue
		loadout_component.unlock_ability(ability.ability_id)

	call_deferred("_emit_selection")

func select_next() -> void:
	if abilities.is_empty() or _casting:
		return

	_selected_index = (
		_selected_index + 1
	) % abilities.size()
	_emit_selection()

func select_previous() -> void:
	if abilities.is_empty() or _casting:
		return

	_selected_index -= 1
	if _selected_index < 0:
		_selected_index = abilities.size() - 1
	_emit_selection()

func get_selected() -> SpecialAttackData:
	if abilities.is_empty():
		return null

	_selected_index = clampi(
		_selected_index,
		0,
		abilities.size() - 1
	)
	return abilities[_selected_index]

func start_cast(
	facing: StringName,
	direction: Vector2
) -> bool:
	if _casting:
		return false

	var data: SpecialAttackData = get_selected()
	if data == null:
		return false

	if not loadout_component.can_use(data.ability_id):
		return false

	if not ki_component.can_consume(data.ki_cost):
		return false

	_casting = true
	_fired = false
	_active_data = data
	_startup_left = maxf(data.startup_duration, 0.0)
	_lock_left = maxf(
		data.startup_duration + data.cast_lock_duration,
		data.startup_duration
	)
	_cast_facing = facing
	_cast_direction = (
		_facing_vector(facing)
		if direction.is_zero_approx()
		else direction.normalized()
	)

	cast_started.emit(data.ability_id)
	return true

func tick_cast(caster: Node2D, delta: float) -> void:
	if not _casting or _active_data == null:
		return

	_startup_left = maxf(_startup_left - delta, 0.0)
	_lock_left = maxf(_lock_left - delta, 0.0)

	if not _fired and _startup_left <= 0.0:
		if not ki_component.consume(_active_data.ki_cost):
			_finish_cast()
			return

		_spawn_attack(caster, _active_data)
		loadout_component.start_cooldown(
			_active_data.ability_id,
			_active_data.cooldown
		)
		_fired = true

	if _lock_left <= 0.0:
		_finish_cast()

func cancel_cast() -> void:
	if not _casting:
		return
	_finish_cast()

func is_casting() -> bool:
	return _casting

func get_cast_facing() -> StringName:
	return _cast_facing

func get_cast_state() -> StringName:
	if (
		_active_data != null
		and _active_data.cast_pose
			== SpecialAttackData.CastPose.BEAM
	):
		return &"special_beam"

	return &"special_projectile"

func _spawn_attack(
	caster: Node2D,
	data: SpecialAttackData
) -> void:
	match data.attack_type:
		SpecialAttackData.AttackType.BEAM:
			_spawn_beam(caster, data)
		SpecialAttackData.AttackType.SPREAD:
			_spawn_spread(caster, data)
		_:
			_spawn_projectile(
				caster,
				data,
				_cast_direction
			)

func _spawn_projectile(
	caster: Node2D,
	data: SpecialAttackData,
	direction: Vector2
) -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate() as SpecialAttackProjectile
	if projectile == null:
		return

	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()

	parent.add_child(projectile)
	projectile.global_position = (
		caster.global_position
		+ direction.normalized() * spawn_distance
	)
	projectile.setup(data, direction, caster)

func _spawn_spread(
	caster: Node2D,
	data: SpecialAttackData
) -> void:
	var count: int = maxi(data.projectile_count, 1)
	if count == 1:
		_spawn_projectile(caster, data, _cast_direction)
		return

	var total_radians: float = deg_to_rad(
		data.spread_degrees
	)
	var start_angle: float = -total_radians * 0.5
	var step: float = total_radians / float(count - 1)

	for index in range(count):
		var angle: float = start_angle + step * float(index)
		var direction: Vector2 = _cast_direction.rotated(angle)
		_spawn_projectile(caster, data, direction)

func _spawn_beam(
	caster: Node2D,
	data: SpecialAttackData
) -> void:
	if beam_scene == null:
		return

	var beam := beam_scene.instantiate() as SpecialAttackBeam
	if beam == null:
		return

	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()

	parent.add_child(beam)
	beam.global_position = (
		caster.global_position
		+ _cast_direction.normalized() * spawn_distance
	)
	beam.setup(data, _cast_direction, caster)

func _finish_cast() -> void:
	var finished_id: StringName = &""
	if _active_data != null:
		finished_id = _active_data.ability_id

	_casting = false
	_fired = false
	_startup_left = 0.0
	_lock_left = 0.0
	_active_data = null

	cast_finished.emit(finished_id)

func _emit_selection() -> void:
	var data: SpecialAttackData = get_selected()
	if data == null:
		return

	selection_changed.emit(
		data.ability_id,
		data.display_name,
		_selected_index
	)

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
