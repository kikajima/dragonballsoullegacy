class_name MeleeCombatComponent
extends Node

signal attack_started(facing: StringName)
signal attack_finished

@export var attack_duration: float = 0.62
@export var hitbox_active_from: float = 0.16
@export var hitbox_active_until: float = 0.42
@export var attack_hitbox_path: NodePath

@onready var attack_hitbox: HitboxComponent = get_node(attack_hitbox_path) as HitboxComponent

var _attacking: bool = false
var _elapsed: float = 0.0

func start_attack(facing: StringName) -> bool:
	if _attacking:
		return false

	_attacking = true
	_elapsed = 0.0
	attack_hitbox.set_facing(facing)
	attack_hitbox.set_active(false)
	attack_started.emit(facing)
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

func _finish_attack() -> void:
	attack_hitbox.set_active(false)
	_attacking = false
	_elapsed = 0.0
	attack_finished.emit()
