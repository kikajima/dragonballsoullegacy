class_name GuardComponent
extends Node

signal guard_changed(active: bool)
signal hit_blocked(original_damage: int, reduced_damage: int)
signal perfect_guarded(original_damage: int, reduced_damage: int)

@export_range(0.0, 1.0, 0.05)
var damage_multiplier: float = 0.25

@export_range(0.0, 1.0, 0.01)
var perfect_damage_multiplier: float = 0.05

@export_range(0.0, 0.5, 0.01)
var perfect_guard_window: float = 0.12

@export_range(-1.0, 1.0, 0.05)
var front_dot_threshold: float = 0.0

var _guarding: bool = false
var _last_hit_blocked: bool = false
var _last_hit_perfect: bool = false
var _guard_time: float = 0.0

func _process(delta: float) -> void:
	if _guarding:
		_guard_time += delta

func set_guarding(active: bool) -> void:
	if _guarding == active:
		return

	_guarding = active
	_guard_time = 0.0
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
	_last_hit_perfect = false

	if not _guarding or damage <= 0:
		return damage

	var to_source: Vector2 = source_position - owner_position
	if to_source.is_zero_approx():
		return damage

	var facing_vector: Vector2 = _facing_vector(facing)
	var source_direction: Vector2 = to_source.normalized()

	if facing_vector.dot(source_direction) < front_dot_threshold:
		return damage

	_last_hit_blocked = true
	var perfect: bool = _guard_time <= perfect_guard_window
	var multiplier: float = (
		perfect_damage_multiplier
		if perfect
		else damage_multiplier
	)
	var reduced_damage: int = maxi(
		1,
		roundi(float(damage) * multiplier)
	)

	if perfect:
		_last_hit_perfect = true
		perfect_guarded.emit(damage, reduced_damage)
	else:
		hit_blocked.emit(damage, reduced_damage)

	_report_guard_feedback(perfect)
	return reduced_damage

func was_last_hit_blocked() -> bool:
	return _last_hit_blocked

func was_last_hit_perfect() -> bool:
	return _last_hit_perfect

func _report_guard_feedback(perfect: bool) -> void:
	var components: Node = get_parent()
	if components == null:
		return

	var actor: Node = components.get_parent()
	if actor == null:
		return

	var feedback: CombatFeedbackManager = (
		get_tree().get_first_node_in_group("combat_feedback")
		as CombatFeedbackManager
	)
	if feedback != null:
		feedback.report_block(actor, perfect)

	if perfect:
		var hit_stop: HitStopComponent = actor.get_node_or_null(
			"Components/HitStopComponent"
		) as HitStopComponent
		if hit_stop != null:
			hit_stop.trigger()

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
