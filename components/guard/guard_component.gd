class_name GuardComponent
extends Node

signal guard_changed(active: bool)
signal hit_blocked(original_damage: int, reduced_damage: int)

@export_range(0.0, 1.0, 0.05)
var damage_multiplier: float = 0.25

@export_range(-1.0, 1.0, 0.05)
var front_dot_threshold: float = 0.0

var _guarding: bool = false
var _last_hit_blocked: bool = false

func set_guarding(active: bool) -> void:
	if _guarding == active:
		return

	_guarding = active
	guard_changed.emit(_guarding)

func is_guarding() -> bool:
	return _guarding

func resolve_damage(
	damage: int,
	owner_position: Vector2,
	source_position: Vector2,
	facing: StringName
) -> int:
	_last_hit_blocked = false

	if not _guarding or damage <= 0:
		return damage

	var to_source := source_position - owner_position
	if to_source.is_zero_approx():
		return damage

	var facing_vector := _facing_vector(facing)
	var source_direction := to_source.normalized()

	if facing_vector.dot(source_direction) < front_dot_threshold:
		return damage

	var reduced_damage := maxi(1, roundi(float(damage) * damage_multiplier))
	_last_hit_blocked = true
	hit_blocked.emit(damage, reduced_damage)
	return reduced_damage

func was_last_hit_blocked() -> bool:
	return _last_hit_blocked

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
