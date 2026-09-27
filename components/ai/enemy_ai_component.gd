class_name EnemyAIComponent
extends Node

signal defensive_action_started(action_name: StringName)
signal successful_block_registered
signal counterattack_queued

enum DefensiveAction {
	NONE,
	BLOCK,
	DODGE,
}

@export var profile: EnemyAIProfile
@export var melee_threat_range: float = 36.0
@export var projectile_corridor_radius: float = 16.0
@export var reaction_jitter: float = 0.12
@export var tactical_strafe_min_distance: float = 34.0
@export var tactical_strafe_max_distance: float = 90.0

var _decision_time_left: float = 0.0
var _guard_time_left: float = 0.0
var _dodge_time_left: float = 0.0
var _strafe_time_left: float = 0.0
var _strafe_cooldown_left: float = 0.0

var _active_action: int = DefensiveAction.NONE
var _dodge_direction: Vector2 = Vector2.ZERO
var _threat_position: Vector2 = Vector2.ZERO
var _strafe_sign: float = 1.0
var _counterattack_pending: bool = false

func _ready() -> void:
	if profile == null:
		profile = EnemyAIProfile.new()

	_reset_decision_timer()

func tick(delta: float) -> void:
	_decision_time_left = maxf(
		_decision_time_left - delta,
		0.0
	)
	_strafe_time_left = maxf(
		_strafe_time_left - delta,
		0.0
	)
	_strafe_cooldown_left = maxf(
		_strafe_cooldown_left - delta,
		0.0
	)

	if _active_action == DefensiveAction.BLOCK:
		_guard_time_left = maxf(
			_guard_time_left - delta,
			0.0
		)
		if _guard_time_left <= 0.0:
			_active_action = DefensiveAction.NONE

	elif _active_action == DefensiveAction.DODGE:
		_dodge_time_left = maxf(
			_dodge_time_left - delta,
			0.0
		)
		if _dodge_time_left <= 0.0:
			_active_action = DefensiveAction.NONE
			_dodge_direction = Vector2.ZERO

func choose_defensive_action(
	owner_actor: Node2D,
	target: Node2D
) -> int:
	if owner_actor == null or target == null:
		return DefensiveAction.NONE

	if _active_action != DefensiveAction.NONE:
		return _active_action

	if _decision_time_left > 0.0:
		return DefensiveAction.NONE

	_reset_decision_timer()

	var projectile: Node2D = _find_projectile_threat(
		owner_actor,
		target
	)
	if projectile != null:
		_threat_position = projectile.global_position

		var distance: float = owner_actor.global_position.distance_to(
			projectile.global_position
		)
		var projectile_direction: Vector2 = Vector2.ZERO

		if projectile.has_method("get_travel_direction"):
			var direction_value: Variant = projectile.call(
				"get_travel_direction"
			)
			if direction_value is Vector2:
				projectile_direction = direction_value

		if (
			distance >= profile.dodge_min_distance
			and randf() <= profile.projectile_dodge_chance
		):
			_begin_dodge(projectile_direction)
			return DefensiveAction.DODGE

		if randf() <= profile.ranged_block_chance:
			_begin_guard()
			return DefensiveAction.BLOCK

	if _is_melee_threat(owner_actor, target):
		_threat_position = target.global_position

		if randf() <= profile.melee_block_chance:
			_begin_guard()
			return DefensiveAction.BLOCK

		var close_dodge_chance: float = (
			profile.projectile_dodge_chance * 0.30
		)
		if (
			profile.intelligence_tier
				>= EnemyAIProfile.IntelligenceTier.ELITE
			and randf() <= close_dodge_chance
		):
			var away: Vector2 = (
				owner_actor.global_position
				- target.global_position
			).normalized()
			_begin_dodge(away)
			return DefensiveAction.DODGE

	return DefensiveAction.NONE

func is_guarding() -> bool:
	return _active_action == DefensiveAction.BLOCK

func is_dodging() -> bool:
	return _active_action == DefensiveAction.DODGE

func get_dodge_direction() -> Vector2:
	return _dodge_direction

func get_dodge_speed_scale() -> float:
	return profile.dodge_speed_scale

func get_threat_position() -> Vector2:
	return _threat_position

func register_successful_block() -> void:
	successful_block_registered.emit()

	if randf() <= profile.counterattack_chance:
		_counterattack_pending = true
		counterattack_queued.emit()

func consume_counterattack() -> bool:
	if not _counterattack_pending:
		return false

	_counterattack_pending = false
	return true

func clear_defense() -> void:
	_active_action = DefensiveAction.NONE
	_guard_time_left = 0.0
	_dodge_time_left = 0.0
	_dodge_direction = Vector2.ZERO
	_counterattack_pending = false

func get_approach_direction(
	to_target: Vector2,
	distance_to_target: float
) -> Vector2:
	if to_target.is_zero_approx():
		return Vector2.ZERO

	var forward: Vector2 = to_target.normalized()

	if (
		distance_to_target < tactical_strafe_min_distance
		or distance_to_target > tactical_strafe_max_distance
	):
		return forward

	if _strafe_time_left <= 0.0 and _strafe_cooldown_left <= 0.0:
		_strafe_cooldown_left = randf_range(0.75, 1.45)

		if randf() <= profile.strafe_chance:
			_strafe_time_left = randf_range(0.30, 0.65)
			_strafe_sign = -1.0 if randf() < 0.5 else 1.0

	if _strafe_time_left <= 0.0:
		return forward

	var side: Vector2 = _perpendicular(forward) * _strafe_sign
	return (
		forward + side * profile.strafe_weight
	).normalized()

func get_tier_name() -> String:
	return profile.get_tier_name()

func _begin_guard() -> void:
	_active_action = DefensiveAction.BLOCK
	_guard_time_left = profile.guard_duration
	_dodge_time_left = 0.0
	_dodge_direction = Vector2.ZERO
	defensive_action_started.emit(&"block")

func _begin_dodge(reference_direction: Vector2) -> void:
	var safe_direction: Vector2 = reference_direction

	if safe_direction.is_zero_approx():
		safe_direction = Vector2.RIGHT

	var side: Vector2 = _perpendicular(
		safe_direction.normalized()
	)

	if randf() < 0.5:
		side = -side

	_active_action = DefensiveAction.DODGE
	_dodge_time_left = profile.dodge_duration
	_guard_time_left = 0.0
	_dodge_direction = side.normalized()
	defensive_action_started.emit(&"dodge")

func _find_projectile_threat(
	owner_actor: Node2D,
	target: Node2D
) -> Node2D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(
		"combat_projectile"
	)
	var best_projectile: Node2D = null
	var best_distance: float = INF

	for node in nodes:
		var projectile: Node2D = node as Node2D
		if projectile == null:
			continue

		if projectile.has_method("is_active_projectile"):
			var active_value: Variant = projectile.call(
				"is_active_projectile"
			)
			if not bool(active_value):
				continue

		if projectile.has_method("get_source_actor"):
			var source_value: Variant = projectile.call(
				"get_source_actor"
			)
			var source_actor: Node = source_value as Node
			if source_actor != null and source_actor != target:
				if not source_actor.is_in_group("player"):
					continue

		var distance: float = owner_actor.global_position.distance_to(
			projectile.global_position
		)
		if distance > profile.projectile_scan_range:
			continue

		var direction: Vector2 = Vector2.ZERO
		if projectile.has_method("get_travel_direction"):
			var direction_value: Variant = projectile.call(
				"get_travel_direction"
			)
			if direction_value is Vector2:
				direction = direction_value

		if direction.is_zero_approx():
			continue

		direction = direction.normalized()

		var to_owner: Vector2 = (
			owner_actor.global_position
			- projectile.global_position
		)
		var forward_distance: float = to_owner.dot(direction)

		if forward_distance <= 0.0:
			continue

		var lateral_distance: float = absf(
			to_owner.cross(direction)
		)

		if lateral_distance > projectile_corridor_radius:
			continue

		if distance < best_distance:
			best_distance = distance
			best_projectile = projectile

	return best_projectile

func _is_melee_threat(
	owner_actor: Node2D,
	target: Node2D
) -> bool:
	var distance: float = owner_actor.global_position.distance_to(
		target.global_position
	)

	if distance > melee_threat_range:
		return false

	if not target.has_method("get_current_state"):
		return false

	var state_value: Variant = target.call("get_current_state")
	var state_name: String = str(state_value)

	return (
		state_name.begins_with("attack_")
		or state_name.begins_with("kick_")
	)

func _reset_decision_timer() -> void:
	var base_time: float = maxf(profile.reaction_time, 0.05)
	var jitter: float = randf_range(
		-reaction_jitter,
		reaction_jitter
	)

	_decision_time_left = maxf(
		base_time + jitter,
		0.04
	)

func _perpendicular(direction: Vector2) -> Vector2:
	return Vector2(-direction.y, direction.x)
