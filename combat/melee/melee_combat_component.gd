class_name MeleeCombatComponent
extends Node

signal attack_started(facing: StringName, variant: int)
signal attack_finished
signal attack_buffered

const ATTACK_PUNCH: StringName = &"punch"
const ATTACK_KICK: StringName = &"kick"
const ATTACK_SWORD: StringName = &"sword"

@export var attack_duration: float = 0.40
@export var damage: int = 10
@export var hitbox_active_from: float = 0.11
@export var hitbox_active_until: float = 0.29
@export var combo_chain_from: float = 0.27
@export var input_buffer_duration: float = 0.30
@export var attack_offset_distance: float = 12.0

@export var kick_duration: float = 0.48
@export var kick_damage: int = 16
@export var kick_hitbox_active_from: float = 0.14
@export var kick_hitbox_active_until: float = 0.34
@export var kick_combo_chain_from: float = 0.34
@export var kick_offset_distance: float = 15.0

@export var punch_to_kick_chain_from: float = 0.34
@export var kick_to_punch_chain_from: float = 0.40

# Sword combo (Future Trunks, LoG II): 1 = horizontal sweep, 2 = thrust,
# 3 = leap + vertical slash finisher. Timings follow the composed frames in
# SwordAnimationLibrary (assets/sprites/equipment/sword/sword_overlay.json).
@export var sword_durations: PackedFloat32Array = PackedFloat32Array([0.42, 0.42, 0.56])
@export var sword_hitbox_from: PackedFloat32Array = PackedFloat32Array([0.08, 0.08, 0.24])
@export var sword_hitbox_until: PackedFloat32Array = PackedFloat32Array([0.26, 0.24, 0.40])
@export var sword_combo_chain_from: PackedFloat32Array = PackedFloat32Array([0.26, 0.26, 0.50])
@export var sword_damage_scale: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.5])
@export var sword_damage: int = 12
@export var sword_offset_distance: float = 16.0
# Hitbox scale for a side swing (x = reach, y = arc height). Up/down swaps it.
@export var sword_hitbox_scale: Vector2 = Vector2(1.45, 2.0)
@export var sword_finisher_hitbox_scale: Vector2 = Vector2(1.7, 1.7)

@export var attack_hitbox_path: NodePath

@onready var attack_hitbox: HitboxComponent = get_node(attack_hitbox_path) as HitboxComponent

var _attacking: bool = false
var _elapsed: float = 0.0
var _current_variant: int = 0
var _current_kind: StringName = ATTACK_PUNCH
var _attack_facing: StringName = &"down"

var _punch_variant: int = 0
var _kick_variant: int = 0
var _sword_variant: int = 0
var _weapon_damage_bonus: int = 0

var _buffered_attack: bool = false
var _buffer_time_left: float = 0.0
var _buffered_facing: StringName = &"down"
var _buffered_kind: StringName = ATTACK_PUNCH
var _damage_multiplier: float = 1.0

func set_damage_multiplier(value: float) -> void:
	_damage_multiplier = maxf(value, 0.0)

func set_weapon_damage_bonus(value: int) -> void:
	_weapon_damage_bonus = maxi(value, 0)

func start_attack(
	facing: StringName,
	attack_kind: StringName = ATTACK_PUNCH
) -> bool:
	if _attacking:
		return false

	_begin_attack(facing, attack_kind)
	return true

func buffer_attack(
	facing: StringName,
	attack_kind: StringName = ATTACK_PUNCH
) -> bool:
	if not _attacking:
		return start_attack(facing, attack_kind)

	_buffered_attack = true
	_buffer_time_left = input_buffer_duration
	_buffered_facing = facing
	_buffered_kind = _sanitize_kind(attack_kind)
	attack_buffered.emit()

	if _elapsed >= _get_combo_chain_from(_buffered_kind):
		_consume_buffered_attack()

	return true

func tick_attack(delta: float) -> void:
	if not _attacking:
		return

	_elapsed += delta

	if _buffered_attack:
		_buffer_time_left -= delta

		if _buffer_time_left <= 0.0:
			_clear_buffer()
		elif _elapsed >= _get_combo_chain_from(_buffered_kind):
			_consume_buffered_attack()
			return

	var hitbox_should_be_active := (
		_elapsed >= _get_hitbox_active_from()
		and _elapsed <= _get_hitbox_active_until()
	)
	attack_hitbox.set_active(hitbox_should_be_active)

	if _elapsed >= _get_attack_duration():
		_finish_attack()

func cancel_attack() -> void:
	if not _attacking:
		return

	_clear_buffer()
	_finish_attack()

func is_attacking() -> bool:
	return _attacking

func get_attack_variant() -> int:
	return _current_variant

func get_attack_kind() -> StringName:
	return _current_kind

func get_attack_state() -> StringName:
	if _current_kind == ATTACK_KICK:
		return StringName("kick_%d" % _current_variant)
	if _current_kind == ATTACK_SWORD:
		return StringName("sword_%d" % _current_variant)

	return StringName("attack_%d" % _current_variant)

func get_attack_facing() -> StringName:
	return _attack_facing

func _begin_attack(facing: StringName, attack_kind: StringName) -> void:
	_current_kind = _sanitize_kind(attack_kind)
	_current_variant = _next_variant(_current_kind)
	_attack_facing = facing
	_attacking = true
	_elapsed = 0.0

	attack_hitbox.set_active(false)
	_configure_hitbox_for_current_attack()
	attack_hitbox.set_facing(_attack_facing)

	attack_started.emit(_attack_facing, _current_variant)

func _consume_buffered_attack() -> void:
	var next_facing := _buffered_facing
	var next_kind := _buffered_kind
	_clear_buffer()
	_begin_attack(next_facing, next_kind)

func _finish_attack() -> void:
	attack_hitbox.set_active(false)
	attack_hitbox.shape_scale = Vector2.ONE
	_attacking = false
	_elapsed = 0.0
	attack_finished.emit()

func _clear_buffer() -> void:
	_buffered_attack = false
	_buffer_time_left = 0.0

func _next_variant(attack_kind: StringName) -> int:
	if attack_kind == ATTACK_SWORD:
		# A fresh sword string always opens with the sweep.
		if not _attacking:
			_sword_variant = 0
		_sword_variant = _sword_variant % 3 + 1
		return _sword_variant

	if attack_kind == ATTACK_KICK:
		_kick_variant = 2 if _kick_variant == 1 else 1
		return _kick_variant

	_punch_variant = 2 if _punch_variant == 1 else 1
	return _punch_variant

func _configure_hitbox_for_current_attack() -> void:
	attack_hitbox.shape_scale = Vector2.ONE
	if _current_kind == ATTACK_SWORD:
		var index := _sword_index()
		attack_hitbox.damage = maxi(
			roundi(
				float(sword_damage + _weapon_damage_bonus)
				* sword_damage_scale[index]
				* _damage_multiplier
			),
			0
		)
		attack_hitbox.offset_distance = sword_offset_distance
		attack_hitbox.shape_scale = (
			sword_finisher_hitbox_scale if index == 2 else sword_hitbox_scale
		)
		return

	if _current_kind == ATTACK_KICK:
		attack_hitbox.damage = maxi(
			roundi(float(kick_damage) * _damage_multiplier),
			0
		)
		attack_hitbox.offset_distance = kick_offset_distance
		return

	attack_hitbox.damage = maxi(
		roundi(float(damage) * _damage_multiplier),
		0
	)
	attack_hitbox.offset_distance = attack_offset_distance

func _sword_index() -> int:
	return clampi(_current_variant - 1, 0, 2)

func _get_attack_duration() -> float:
	if _current_kind == ATTACK_SWORD:
		return sword_durations[_sword_index()]
	return kick_duration if _current_kind == ATTACK_KICK else attack_duration

func _get_hitbox_active_from() -> float:
	if _current_kind == ATTACK_SWORD:
		return sword_hitbox_from[_sword_index()]
	return (
		kick_hitbox_active_from
		if _current_kind == ATTACK_KICK
		else hitbox_active_from
	)

func _get_hitbox_active_until() -> float:
	if _current_kind == ATTACK_SWORD:
		return sword_hitbox_until[_sword_index()]
	return (
		kick_hitbox_active_until
		if _current_kind == ATTACK_KICK
		else hitbox_active_until
	)

func _get_combo_chain_from(next_kind: StringName) -> float:
	var safe_next_kind := _sanitize_kind(next_kind)

	if _current_kind == ATTACK_SWORD:
		return sword_combo_chain_from[_sword_index()]

	if _current_kind == ATTACK_PUNCH and safe_next_kind == ATTACK_KICK:
		return punch_to_kick_chain_from

	if _current_kind == ATTACK_KICK and safe_next_kind == ATTACK_PUNCH:
		return kick_to_punch_chain_from

	return (
		kick_combo_chain_from
		if _current_kind == ATTACK_KICK
		else combo_chain_from
	)

func _sanitize_kind(attack_kind: StringName) -> StringName:
	if attack_kind == ATTACK_KICK or attack_kind == ATTACK_SWORD:
		return attack_kind
	return ATTACK_PUNCH
