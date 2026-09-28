class_name SpecialAttackComponent
extends Node

const DEFAULT_ABILITY_RESOURCES := [
	preload("res://data/abilities/special/kamehameha.tres"),
	preload("res://data/abilities/special/spirit_bomb.tres"),
	preload("res://data/abilities/special/masenko_ha.tres"),
	preload("res://data/abilities/special/special_beam_cannon.tres"),
	preload("res://data/abilities/special/scatter_shot.tres"),
	preload("res://data/abilities/special/big_bang_attack.tres"),
	preload("res://data/abilities/special/energy_punch.tres"),
	preload("res://data/abilities/special/burning_attack.tres"),
	preload("res://data/abilities/special/sword_blast.tres"),
	preload("res://data/abilities/special/super_kick.tres"),
	preload("res://data/abilities/special/spin_punch.tres"),
	preload("res://data/abilities/special/two_handed_smash.tres"),
	preload("res://data/abilities/special/cross_slash.tres"),
	preload("res://data/abilities/special/flurry_punch.tres"),
	preload("res://data/abilities/special/peace_sign_pose.tres"),
	preload("res://data/abilities/special/super_saiyan.tres"),
	preload("res://data/abilities/special/super_namek.tres"),
]

signal selection_changed(
	ability_id: StringName,
	display_name: String,
	index: int
)
signal cast_started(ability_id: StringName)
signal cast_finished(ability_id: StringName)
signal charge_changed(ability_id: StringName, ratio: float)

@export var abilities: Array[SpecialAttackData] = []
@export var projectile_scene: PackedScene
@export var beam_scene: PackedScene
@export var charge_preview_scene: PackedScene
@export var ki_component_path: NodePath
@export var loadout_component_path: NodePath
@export var transformation_component_path: NodePath
@export var experience_component_path: NodePath
@export var spawn_distance: float = 20.0

# Prototype convenience only. Character creation can disable this and grant
# skills through progression/loadout data without changing combat code.
@export var unlock_all_for_prototype: bool = true

@onready var ki_component: KiComponent = get_node(
	ki_component_path
) as KiComponent

@onready var loadout_component: AbilityLoadoutComponent = get_node(
	loadout_component_path
) as AbilityLoadoutComponent

@onready var transformation_component: TransformationComponent = get_node(
	transformation_component_path
) as TransformationComponent

@onready var experience_component: ExperienceComponent = get_node(
	experience_component_path
) as ExperienceComponent

var _selected_index: int = 0
var _casting: bool = false
var _fired: bool = false
var _startup_left: float = 0.0
var _lock_left: float = 0.0
var _charge_time: float = 0.0
var _cast_facing: StringName = &"down"
var _cast_direction: Vector2 = Vector2.DOWN
var _active_data: SpecialAttackData
var _active_beam: SpecialAttackBeam
var _charge_preview: SpecialChargePreview
var _flurry_hits_left: int = 0
var _flurry_bonus_hits_added: int = 0
var _flurry_tick_left: float = 0.0
var _damage_multiplier: float = 1.0

func set_damage_multiplier(value: float) -> void:
	_damage_multiplier = maxf(value, 0.0)

func _ready() -> void:
	if abilities.is_empty():
		for resource in DEFAULT_ABILITY_RESOURCES:
			abilities.append(resource as SpecialAttackData)

	if unlock_all_for_prototype:
		for ability in abilities:
			if ability == null or ability.ability_id == &"":
				continue
			loadout_component.unlock_ability(ability.ability_id)

	_selected_index = _find_next_available_index(
		-1,
		1
	)
	if _selected_index < 0:
		_selected_index = 0

	call_deferred("_emit_selection")

func select_next() -> void:
	if abilities.is_empty() or _casting:
		return

	var next_index: int = _find_next_available_index(
		_selected_index,
		1
	)
	if next_index < 0:
		return

	_selected_index = next_index
	_emit_selection()

func select_previous() -> void:
	if abilities.is_empty() or _casting:
		return

	var next_index: int = _find_next_available_index(
		_selected_index,
		-1
	)
	if next_index < 0:
		return

	_selected_index = next_index
	_emit_selection()

func get_selected() -> SpecialAttackData:
	if abilities.is_empty():
		return null

	_selected_index = clampi(
		_selected_index,
		0,
		abilities.size() - 1
	)

	var selected: SpecialAttackData = abilities[_selected_index]
	if _is_available(selected):
		return selected

	var available_index: int = _find_next_available_index(
		_selected_index - 1,
		1
	)
	if available_index < 0:
		return null

	_selected_index = available_index
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

	if (
		unlock_all_for_prototype
		and not loadout_component.is_unlocked(data.ability_id)
	):
		loadout_component.unlock_ability(data.ability_id)

	if not loadout_component.can_use(data.ability_id):
		return false

	if not ki_component.can_consume(data.ki_cost):
		return false

	_casting = true
	_fired = false
	_active_data = data
	_startup_left = maxf(data.startup_duration, 0.0)
	_lock_left = 0.0
	_charge_time = 0.0
	_flurry_hits_left = 0
	_flurry_bonus_hits_added = 0
	_flurry_tick_left = 0.0
	_cast_facing = facing
	_cast_direction = (
		_facing_vector(facing)
		if direction.is_zero_approx()
		else direction.normalized()
	)

	cast_started.emit(data.ability_id)
	charge_changed.emit(data.ability_id, 0.0)
	return true

func tick_cast(
	caster: Node2D,
	delta: float,
	input_held: bool
) -> void:
	if not _casting or _active_data == null:
		return

	_startup_left = maxf(
		_startup_left - delta,
		0.0
	)
	if _startup_left > 0.0:
		return

	match _active_data.attack_type:
		SpecialAttackData.AttackType.CONTINUOUS_BEAM:
			_tick_continuous_beam(
				caster,
				delta,
				input_held
			)
			return
		SpecialAttackData.AttackType.FLURRY:
			_tick_flurry(caster, delta)
			return

	if _active_data.is_charge_attack() and not _fired:
		if input_held:
			_charge_time = minf(
				_charge_time + delta,
				_active_data.charge_duration
			)
			_update_charge_preview(caster)
			charge_changed.emit(
				_active_data.ability_id,
				get_charge_ratio()
			)
			return

		_clear_charge_preview()
		_fire_once(caster, get_charge_ratio())

	if not _fired:
		_fire_once(caster, 0.0)

	if not _fired:
		return

	_lock_left = maxf(_lock_left - delta, 0.0)
	if _lock_left <= 0.0:
		_finish_cast(true)

func add_flurry_bonus_hit() -> bool:
	if (
		not _casting
		or _active_data == null
		or _active_data.attack_type
			!= SpecialAttackData.AttackType.FLURRY
		or not _fired
	):
		return false

	if (
		_flurry_bonus_hits_added
		>= _active_data.flurry_bonus_hit_limit
	):
		return false

	_flurry_bonus_hits_added += 1
	_flurry_hits_left += 1
	_lock_left += maxf(
		_active_data.flurry_hit_interval,
		0.05
	)
	return true

func cancel_cast() -> void:
	if not _casting:
		return

	_finish_cast(_fired)

func is_casting() -> bool:
	return _casting

func get_cast_facing() -> StringName:
	return _cast_facing

func get_cast_state() -> StringName:
	if _active_data == null:
		return &"special_projectile"

	# HU2 uses a dedicated "charge" character state while preparing a
	# beam, then switches to "Beam" only when the attack is actually fired.
	if (
		_active_data.attack_type
			== SpecialAttackData.AttackType.CONTINUOUS_BEAM
		and _active_data.charge_duration > 0.0
		and not _fired
	):
		return &"special_beam_charge"

	return _active_data.get_cast_state()

func get_charge_ratio() -> float:
	if (
		_active_data == null
		or _active_data.charge_duration <= 0.0
	):
		return 0.0

	return clampf(
		_charge_time / _active_data.charge_duration,
		0.0,
		1.0
	)

func is_charging() -> bool:
	return (
		_casting
		and not _fired
		and _active_data != null
		and _active_data.is_charge_attack()
		and _startup_left <= 0.0
	)

func _tick_continuous_beam(
	caster: Node2D,
	delta: float,
	input_held: bool
) -> void:
	if not _fired and _active_data.charge_duration > 0.0:
		# Charged beams have a preparation phase before the actual beam
		# exists. Holding the input fills the charge; releasing too early
		# cancels without consuming Ki or starting cooldown.
		if not input_held:
			_finish_cast(false)
			return

		_charge_time = minf(
			_charge_time + delta,
			_active_data.charge_duration
		)
		_update_charge_preview(caster)
		charge_changed.emit(
			_active_data.ability_id,
			get_charge_ratio()
		)

		if _charge_time < _active_data.charge_duration:
			return

		_clear_charge_preview()

	if not _fired:
		if not ki_component.consume(_active_data.ki_cost):
			_finish_cast(false)
			return

		_active_beam = _spawn_beam(
			caster,
			_active_data
		)
		_fired = _active_beam != null
		if not _fired:
			_finish_cast(false)
			return

	if not input_held:
		_finish_cast(true)
		return

	var drain: float = maxf(
		_active_data.ki_drain_per_second,
		0.0
	) * delta

	if drain > 0.0 and not ki_component.consume(drain):
		_finish_cast(true)
		return

	if is_instance_valid(_active_beam):
		_active_beam.follow_caster(
			caster,
			_cast_direction,
			spawn_distance
		)

func _tick_flurry(
	caster: Node2D,
	delta: float
) -> void:
	if not _fired:
		if not ki_component.consume(_active_data.ki_cost):
			_finish_cast(false)
			return

		_fired = true
		_flurry_hits_left = maxi(
			_active_data.flurry_hit_count,
			1
		)
		_flurry_tick_left = 0.0
		_lock_left = maxf(
			_active_data.cast_lock_duration,
			float(_flurry_hits_left)
				* _active_data.flurry_hit_interval
		)

	_flurry_tick_left -= delta
	_lock_left = maxf(_lock_left - delta, 0.0)

	while (
		_flurry_hits_left > 0
		and _flurry_tick_left <= 0.0
	):
		var is_final: bool = _flurry_hits_left == 1
		var damage_scale: float = 1.35 if is_final else 1.0
		_perform_melee_hit(
			caster,
			_active_data,
			damage_scale,
			not is_final
		)
		_flurry_hits_left -= 1
		_flurry_tick_left += maxf(
			_active_data.flurry_hit_interval,
			0.05
		)

	if _flurry_hits_left <= 0 and _lock_left <= 0.0:
		_finish_cast(true)

func _fire_once(
	caster: Node2D,
	charge_ratio: float
) -> void:
	if _active_data == null or _fired:
		return

	if not ki_component.consume(_active_data.ki_cost):
		_finish_cast(false)
		return

	match _active_data.attack_type:
		SpecialAttackData.AttackType.PROJECTILE:
			_spawn_projectile(
				caster,
				_active_data,
				_cast_direction,
				charge_ratio
			)
		SpecialAttackData.AttackType.SPREAD:
			_spawn_spread(
				caster,
				_active_data,
				charge_ratio
			)
		SpecialAttackData.AttackType.ARC_GRENADE:
			_spawn_projectile(
				caster,
				_active_data,
				_cast_direction,
				charge_ratio
			)
		SpecialAttackData.AttackType.CHARGED_PROJECTILE:
			_spawn_projectile(
				caster,
				_active_data,
				_cast_direction,
				charge_ratio
			)
		SpecialAttackData.AttackType.MELEE:
			_dash_caster(
				caster,
				_active_data.dash_distance,
				1.0
			)
			_perform_melee_hit(
				caster,
				_active_data,
				1.0
			)
		SpecialAttackData.AttackType.CHARGED_MELEE:
			var charge_scale: float = lerpf(
				0.75,
				1.0,
				charge_ratio
			)
			_dash_caster(
				caster,
				_active_data.dash_distance,
				charge_scale
			)
			_perform_melee_hit(
				caster,
				_active_data,
				lerpf(
					1.0,
					_active_data.charge_damage_multiplier,
					charge_ratio
				)
			)
		SpecialAttackData.AttackType.AREA_STATUS:
			_perform_area_status(
				caster,
				_active_data
			)
		SpecialAttackData.AttackType.SWORD_WAVE:
			_perform_melee_hit(
				caster,
				_active_data,
				1.0
			)
			_spawn_projectile(
				caster,
				_active_data,
				_cast_direction,
				charge_ratio
			)
		SpecialAttackData.AttackType.TRANSFORMATION:
			if not _toggle_transformation(_active_data):
				_finish_cast(false)
				return

	_fired = true
	_lock_left = maxf(
		_active_data.cast_lock_duration,
		0.01
	)

func _update_charge_preview(caster: Node2D) -> void:
	if _active_data == null or charge_preview_scene == null:
		return

	# HU2 beam charging is already drawn inside the character's "charge"
	# DMI state (hands back + blue energy). Do not overlay KameStart here;
	# KameStart belongs to the fired beam itself.
	var supports_preview := (
		_active_data.attack_type
			== SpecialAttackData.AttackType.CHARGED_PROJECTILE
	)
	if not supports_preview:
		return

	if not is_instance_valid(_charge_preview):
		_charge_preview = (
			charge_preview_scene.instantiate()
			as SpecialChargePreview
		)
		if _charge_preview == null:
			return

		var parent: Node = caster.get_tree().current_scene
		if parent == null:
			parent = caster.get_parent()

		parent.add_child(_charge_preview)
		_charge_preview.setup(
			_active_data.effect_key,
			caster,
			_cast_direction,
			spawn_distance,
			maxf(
				_active_data.charge_scale_multiplier,
				1.0
			)
		)

	_charge_preview.set_charge_ratio(
		get_charge_ratio()
	)

func _clear_charge_preview() -> void:
	if is_instance_valid(_charge_preview):
		_charge_preview.queue_free()

	_charge_preview = null

func _spawn_projectile(
	caster: Node2D,
	data: SpecialAttackData,
	direction: Vector2,
	charge_ratio: float
) -> SpecialAttackProjectile:
	if projectile_scene == null:
		return null

	var projectile := (
		projectile_scene.instantiate()
		as SpecialAttackProjectile
	)
	if projectile == null:
		return null

	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()

	parent.add_child(projectile)
	projectile.global_position = (
		caster.global_position
		+ direction.normalized() * spawn_distance
	)
	projectile.setup(
		_runtime_damage_data(data),
		direction,
		caster,
		charge_ratio
	)
	return projectile

func _spawn_spread(
	caster: Node2D,
	data: SpecialAttackData,
	charge_ratio: float
) -> void:
	var count: int = maxi(data.projectile_count, 1)
	if count == 1:
		_spawn_projectile(
			caster,
			data,
			_cast_direction,
			charge_ratio
		)
		return

	var total_radians: float = deg_to_rad(
		data.spread_degrees
	)
	var start_angle: float = -total_radians * 0.5
	var step: float = total_radians / float(count - 1)

	for index in range(count):
		var angle: float = (
			start_angle + step * float(index)
		)
		var direction: Vector2 = (
			_cast_direction.rotated(angle)
		)
		_spawn_projectile(
			caster,
			data,
			direction,
			charge_ratio
		)

func _spawn_beam(
	caster: Node2D,
	data: SpecialAttackData
) -> SpecialAttackBeam:
	if beam_scene == null:
		return null

	var beam := (
		beam_scene.instantiate()
		as SpecialAttackBeam
	)
	if beam == null:
		return null

	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()

	parent.add_child(beam)
	beam.setup(
		_runtime_damage_data(data),
		_cast_direction,
		caster,
		spawn_distance
	)
	return beam

func _perform_melee_hit(
	caster: Node2D,
	data: SpecialAttackData,
	damage_scale: float,
	suppress_knockback: bool = false
) -> void:
	var shape := CircleShape2D.new()
	shape.radius = maxf(data.melee_radius, 1.0)

	var center: Vector2 = caster.global_position
	if not data.melee_is_radial:
		center += _cast_direction * data.melee_reach

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = _target_collision_mask(caster)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results: Array[Dictionary] = (
		caster.get_world_2d()
		.direct_space_state
		.intersect_shape(query, 32)
	)

	var hit_ids: Dictionary = {}
	for result in results:
		var collider_value: Variant = result.get(
			"collider",
			null
		)
		var receiver := collider_value as Area2D
		if (
			receiver == null
			or not receiver.has_method("receive_hit")
		):
			continue

		var receiver_id: int = receiver.get_instance_id()
		if hit_ids.has(receiver_id):
			continue
		hit_ids[receiver_id] = true

		var resolved_damage: int = maxi(
			roundi(
				float(data.damage)
				* damage_scale
				* _damage_multiplier
			),
			0
		)
		var suppressed_knockback: KnockbackComponent = null
		if suppress_knockback:
			suppressed_knockback = _suppress_receiver_knockback(
				receiver
			)

		var applied: int = int(
			receiver.call(
				"receive_hit",
				resolved_damage,
				caster.global_position
			)
		)

		if suppressed_knockback != null:
			suppressed_knockback.clear_start_suppression()

		if applied <= 0:
			continue

		_apply_status_to_receiver(
			receiver,
			data.stun_duration
		)
		_report_hit(
			caster,
			receiver,
			applied
		)

func _suppress_receiver_knockback(
	receiver: Area2D
) -> KnockbackComponent:
	var actor: Node = receiver.get_parent()
	if actor == null:
		return null

	var knockback := actor.get_node_or_null(
		"Components/KnockbackComponent"
	) as KnockbackComponent
	if knockback != null:
		knockback.suppress_next_start()

	return knockback

func _perform_area_status(
	caster: Node2D,
	data: SpecialAttackData
) -> void:
	var target_group: StringName = (
		&"player"
		if caster.is_in_group("enemy")
		else &"enemy"
	)

	for node in caster.get_tree().get_nodes_in_group(
		target_group
	):
		var actor := node as Node2D
		if actor == null:
			continue

		if (
			caster.global_position.distance_to(
				actor.global_position
			) > data.area_radius
		):
			continue

		var status := actor.get_node_or_null(
			"Components/StatusEffectComponent"
		) as StatusEffectComponent
		if status != null:
			status.apply_status(
				&"stun",
				data.stun_duration,
				1.0
			)

func _dash_caster(
	caster: Node2D,
	distance: float,
	scale_value: float
) -> void:
	if distance <= 0.0:
		return

	var body := caster as CharacterBody2D
	if body == null:
		caster.global_position += (
			_cast_direction
			* distance
			* scale_value
		)
		return

	body.move_and_collide(
		_cast_direction
		* distance
		* scale_value
	)

func _apply_status_to_receiver(
	receiver: Area2D,
	duration: float
) -> void:
	if duration <= 0.0:
		return

	var actor: Node = receiver.get_parent()
	if actor == null:
		return

	var status := actor.get_node_or_null(
		"Components/StatusEffectComponent"
	) as StatusEffectComponent
	if status != null:
		status.apply_status(
			&"stun",
			duration,
			1.0
		)

func _report_hit(
	caster: Node,
	target: Node,
	damage: int
) -> void:
	if (
		damage > 0
		and caster != null
		and caster.has_method("register_combat_hit")
	):
		caster.call(
			"register_combat_hit",
			target,
			damage
		)

func _runtime_damage_data(data: SpecialAttackData) -> SpecialAttackData:
	if data == null or is_equal_approx(_damage_multiplier, 1.0):
		return data

	var runtime := data.duplicate() as SpecialAttackData
	if runtime == null:
		return data

	runtime.damage = maxi(
		roundi(float(data.damage) * _damage_multiplier),
		0
	)
	return runtime

func _toggle_transformation(data: SpecialAttackData) -> bool:
	if (
		data == null
		or data.transformation_id == &""
		or transformation_component == null
	):
		return false

	if (
		transformation_component.active_transformation
		== data.transformation_id
	):
		transformation_component.end_transformation()
		return true

	var current_level: int = 1
	if experience_component != null:
		current_level = experience_component.current_level

	return transformation_component.start_transformation(
		data.transformation_id,
		current_level
	)

func is_transformation_active(
	transformation_id: StringName
) -> bool:
	return (
		transformation_component != null
		and transformation_component.active_transformation
		== transformation_id
	)

func _finish_cast(start_cooldown: bool) -> void:
	var finished_id: StringName = &""

	if _active_data != null:
		finished_id = _active_data.ability_id

		if start_cooldown:
			loadout_component.start_cooldown(
				_active_data.ability_id,
				_active_data.cooldown
			)

	if is_instance_valid(_active_beam):
		_active_beam.stop_beam()

	_clear_charge_preview()
	_active_beam = null
	_casting = false
	_fired = false
	_startup_left = 0.0
	_lock_left = 0.0
	_charge_time = 0.0
	_flurry_hits_left = 0
	_flurry_bonus_hits_added = 0
	_flurry_tick_left = 0.0
	_active_data = null

	if finished_id != &"":
		charge_changed.emit(finished_id, 0.0)

	cast_finished.emit(finished_id)

func _find_next_available_index(
	from_index: int,
	step: int
) -> int:
	if abilities.is_empty():
		return -1

	var count: int = abilities.size()
	var index: int = from_index

	for _attempt in range(count):
		index = (index + step + count) % count
		var data: SpecialAttackData = abilities[index]
		if _is_available(data):
			return index

	return -1

func _is_available(data: SpecialAttackData) -> bool:
	if data == null or data.ability_id == &"":
		return false

	if unlock_all_for_prototype:
		return true

	return loadout_component.is_unlocked(data.ability_id)

func _emit_selection() -> void:
	var data: SpecialAttackData = get_selected()
	if data == null:
		return

	selection_changed.emit(
		data.ability_id,
		data.display_name,
		_selected_index
	)

func _target_collision_mask(caster: Node) -> int:
	if caster != null and caster.is_in_group("enemy"):
		return 2

	return 4

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
