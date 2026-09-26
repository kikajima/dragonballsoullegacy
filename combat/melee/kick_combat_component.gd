class_name KickCombatComponent
extends Node

signal kick_started(facing: StringName)
signal kick_finished

@export var kick_duration: float = 0.48
@export var hitbox_active_from: float = 0.14
@export var hitbox_active_until: float = 0.34
@export var damage: int = 16
@export var attack_hitbox_path: NodePath

@onready var attack_hitbox: HitboxComponent = get_node(attack_hitbox_path) as HitboxComponent

var _kicking: bool = false
var _elapsed: float = 0.0
var _kick_facing: StringName = &"down"

func start_kick(facing: StringName) -> bool:
	if _kicking:
		return false

	_kicking = true
	_elapsed = 0.0
	_kick_facing = facing
	attack_hitbox.damage = damage
	attack_hitbox.set_facing(_kick_facing)
	attack_hitbox.set_active(false)
	kick_started.emit(_kick_facing)
	return true

func tick_kick(delta: float) -> void:
	if not _kicking:
		return

	_elapsed += delta

	var hitbox_should_be_active := (
		_elapsed >= hitbox_active_from
		and _elapsed <= hitbox_active_until
	)
	attack_hitbox.set_active(hitbox_should_be_active)

	if _elapsed >= kick_duration:
		_finish_kick()

func cancel_kick() -> void:
	if not _kicking:
		return
	_finish_kick()

func is_kicking() -> bool:
	return _kicking

func get_kick_facing() -> StringName:
	return _kick_facing

func _finish_kick() -> void:
	attack_hitbox.set_active(false)
	_kicking = false
	_elapsed = 0.0
	kick_finished.emit()
