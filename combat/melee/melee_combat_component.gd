class_name MeleeCombatComponent
extends Node

signal attack_started(facing: StringName, variant: int)
signal attack_finished
signal attack_buffered

@export var attack_duration: float = 0.40
@export var hitbox_active_from: float = 0.11
@export var hitbox_active_until: float = 0.29
@export var combo_chain_from: float = 0.26
@export var input_buffer_duration: float = 0.22
@export var attack_hitbox_path: NodePath

@onready var attack_hitbox: HitboxComponent = get_node(attack_hitbox_path) as HitboxComponent

var _attacking: bool = false
var _elapsed: float = 0.0
var _current_variant: int = 0
var _attack_facing: StringName = &"down"

var _buffered_attack: bool = false
var _buffer_time_left: float = 0.0
var _buffered_facing: StringName = &"down"

func start_attack(facing: StringName) -> bool:
	if _attacking:
		return false

	_begin_attack(facing)
	return true

func buffer_attack(facing: StringName) -> bool:
	if not _attacking:
		return start_attack(facing)

	_buffered_attack = true
	_buffer_time_left = input_buffer_duration
	_buffered_facing = facing
	attack_buffered.emit()

	if _elapsed >= combo_chain_from:
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
		elif _elapsed >= combo_chain_from:
			_consume_buffered_attack()
			return

	var hitbox_should_be_active := (
		_elapsed >= hitbox_active_from
		and _elapsed <= hitbox_active_until
	)
	attack_hitbox.set_active(hitbox_should_be_active)

	if _elapsed >= attack_duration:
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

func get_attack_state() -> StringName:
	return StringName("attack_%d" % _current_variant)

func get_attack_facing() -> StringName:
	return _attack_facing

func _begin_attack(facing: StringName) -> void:
	_current_variant = 2 if _current_variant == 1 else 1
	_attack_facing = facing
	_attacking = true
	_elapsed = 0.0
	attack_hitbox.set_facing(_attack_facing)
	attack_hitbox.set_active(false)
	attack_started.emit(_attack_facing, _current_variant)

func _consume_buffered_attack() -> void:
	var next_facing := _buffered_facing
	_clear_buffer()
	_begin_attack(next_facing)

func _finish_attack() -> void:
	attack_hitbox.set_active(false)
	_attacking = false
	_elapsed = 0.0
	attack_finished.emit()

func _clear_buffer() -> void:
	_buffered_attack = false
	_buffer_time_left = 0.0
