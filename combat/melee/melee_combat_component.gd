class_name MeleeCombatComponent
extends Node

signal attack_started(facing: StringName, variant: int)
signal attack_finished

@export var attack_duration: float = 0.32
@export var hitbox_active_from: float = 0.08
@export var hitbox_active_until: float = 0.22
@export var attack_hitbox_path: NodePath

@onready var attack_hitbox: HitboxComponent = get_node(attack_hitbox_path) as HitboxComponent

var _attacking: bool = false
var _elapsed: float = 0.0
var _current_variant: int = 0

func start_attack(facing: StringName) -> bool:
	if _attacking:
		return false

	_current_variant = 1 if _current_variant == 2 else 2
	_attacking = true
	_elapsed = 0.0
	attack_hitbox.set_facing(facing)
	attack_hitbox.set_active(false)
	attack_started.emit(facing, _current_variant)
	return true

func tick_attack(delta: float) -> void:
	if not _attacking:
		return

	_elapsed += delta

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
	_finish_attack()

func is_attacking() -> bool:
	return _attacking

func get_attack_variant() -> int:
	return _current_variant

func get_attack_state() -> StringName:
	return StringName("attack_%d" % _current_variant)

func _finish_attack() -> void:
	attack_hitbox.set_active(false)
	_attacking = false
	_elapsed = 0.0
	attack_finished.emit()
