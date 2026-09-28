class_name TrainingManager
extends Node

signal session_changed(mode: StringName, active: bool)
signal progress_changed(
	mode: StringName,
	session_xp: int,
	combo: int,
	best_combo: int
)
signal gravity_changed(multiplier: float)
signal prompt_changed(text: String)

const MODE_NONE: StringName = &""
const MODE_GRAVITY: StringName = &"gravity"
const MODE_PUNCHING_BAG: StringName = &"punching_bag"
const MODE_TREADMILL: StringName = &"treadmill"
const MODE_SPARRING: StringName = &"sparring"

const GRAVITY_LEVELS := PackedFloat32Array([1.0, 2.0, 5.0, 10.0])

var active_mode: StringName = MODE_NONE
var gravity_multiplier: float = 1.0
var session_xp: int = 0
var combo: int = 0
var best_combo: int = 0
var total_training_xp: int = 0
var training_sessions: int = 0
var treadmill_distance: float = 0.0
var modes_tried: Dictionary = {}

var _player: Node
var _treadmill_anchor: Vector2 = Vector2.ZERO
var _treadmill_reward_left: float = 1.0

func _ready() -> void:
	call_deferred("_bind_player")

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

func start_training(mode: StringName) -> bool:
	if mode == MODE_NONE:
		return false

	if active_mode == mode:
		return true

	if active_mode != MODE_NONE:
		stop_training()

	active_mode = mode
	session_xp = 0
	combo = 0
	training_sessions += 1
	modes_tried[String(mode)] = true
	session_changed.emit(active_mode, true)
	_emit_progress()

	var stats := get_tree().get_first_node_in_group(
		"game_stats"
	) as GameStatsManager
	if stats != null:
		stats.register_training_session()

	return true

func stop_training() -> void:
	if active_mode == MODE_NONE:
		return

	var previous: StringName = active_mode
	active_mode = MODE_NONE
	combo = 0
	prompt_changed.emit("")
	session_changed.emit(previous, false)
	_emit_progress()

func set_gravity(multiplier: float) -> float:
	var resolved: float = 1.0
	var nearest_distance: float = INF

	for value in GRAVITY_LEVELS:
		var distance: float = absf(value - multiplier)
		if distance < nearest_distance:
			nearest_distance = distance
			resolved = value

	gravity_multiplier = resolved
	gravity_changed.emit(gravity_multiplier)
	return gravity_multiplier

func cycle_gravity() -> float:
	var current_index: int = 0
	for index in range(GRAVITY_LEVELS.size()):
		if is_equal_approx(
			GRAVITY_LEVELS[index],
			gravity_multiplier
		):
			current_index = index
			break

	var next_index: int = (
		current_index + 1
	) % GRAVITY_LEVELS.size()

	return set_gravity(GRAVITY_LEVELS[next_index])

func reset_training_environment() -> void:
	stop_training()
	set_gravity(1.0)

func register_success(base_xp: int = 2) -> int:
	if active_mode == MODE_NONE:
		return 0

	combo += 1
	best_combo = maxi(best_combo, combo)

	var combo_multiplier: float = 1.0 + minf(
		float(combo),
		50.0
	) * 0.02
	var reward: int = maxi(
		roundi(
			float(maxi(base_xp, 1))
			* gravity_multiplier
			* combo_multiplier
		),
		1
	)

	return _award_xp(reward)

func register_passive_progress(base_xp: int = 1) -> int:
	if active_mode == MODE_NONE:
		return 0

	var reward: int = maxi(
		roundi(
			float(maxi(base_xp, 1))
			* sqrt(gravity_multiplier)
		),
		1
	)
	return _award_xp(reward)

func register_miss() -> void:
	combo = 0
	_emit_progress()

	if gravity_multiplier <= 1.0:
		return

	_apply_gravity_mistake_damage()

func set_prompt(text_value: String) -> void:
	prompt_changed.emit(text_value)

func start_treadmill(anchor: Vector2) -> bool:
	if not start_training(MODE_TREADMILL):
		return false

	_treadmill_anchor = anchor
	_treadmill_reward_left = 1.0
	return true

func is_treadmill_active() -> bool:
	return active_mode == MODE_TREADMILL

func get_treadmill_anchor() -> Vector2:
	return _treadmill_anchor

func tick_treadmill(
	input_strength: float,
	running: bool,
	delta: float
) -> void:
	if not is_treadmill_active():
		return

	var safe_strength: float = clampf(input_strength, 0.0, 1.0)
	if safe_strength <= 0.05:
		set_prompt("MOVE TO RUN")
		return

	var speed_factor: float = 1.5 if running else 1.0
	treadmill_distance += (
		safe_strength
		* speed_factor
		* gravity_multiplier
		* delta
	)

	set_prompt(
		"RUN  %.0fm" % treadmill_distance
	)

	_treadmill_reward_left -= delta
	if _treadmill_reward_left > 0.0:
		return

	_treadmill_reward_left += 1.0
	register_passive_progress(2 if running else 1)

func get_movement_multiplier() -> float:
	if gravity_multiplier <= 1.0:
		return 1.0

	return clampf(
		1.0 / sqrt(gravity_multiplier),
		0.34,
		1.0
	)

func serialize_state() -> Dictionary:
	return {
		"gravity_multiplier": gravity_multiplier,
		"best_combo": best_combo,
		"total_training_xp": total_training_xp,
		"training_sessions": training_sessions,
		"treadmill_distance": treadmill_distance,
		"modes_tried": modes_tried.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	gravity_multiplier = maxf(
		float(data.get("gravity_multiplier", 1.0)),
		1.0
	)
	best_combo = maxi(int(data.get("best_combo", 0)), 0)
	total_training_xp = maxi(
		int(data.get("total_training_xp", 0)),
		0
	)
	training_sessions = maxi(
		int(data.get("training_sessions", 0)),
		0
	)
	treadmill_distance = maxf(
		float(data.get("treadmill_distance", 0.0)),
		0.0
	)

	var modes_value: Variant = data.get("modes_tried", {})
	if modes_value is Dictionary:
		modes_tried = (modes_value as Dictionary).duplicate(true)

	gravity_changed.emit(gravity_multiplier)
	_emit_progress()

func _award_xp(amount: int) -> int:
	if amount <= 0:
		return 0

	if _player == null or not is_instance_valid(_player):
		_bind_player()
	if _player == null:
		return 0

	var experience := _player.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent
	if experience == null:
		return 0

	var applied: int = experience.add_experience(amount)
	if applied <= 0:
		return 0

	session_xp += applied
	total_training_xp += applied
	_emit_progress()

	var stats := get_tree().get_first_node_in_group(
		"game_stats"
	) as GameStatsManager
	if stats != null:
		stats.register_training_xp(applied)

	return applied

func _apply_gravity_mistake_damage() -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_player()
	if _player == null:
		return

	var health := _player.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health == null or health.is_dead():
		return

	var ratio: float = clampf(
		0.025 * gravity_multiplier,
		0.05,
		0.25
	)
	var damage: int = maxi(
		roundi(float(health.max_health) * ratio),
		1
	)
	health.take_damage(damage)

func _emit_progress() -> void:
	progress_changed.emit(
		active_mode,
		session_xp,
		combo,
		best_combo
	)
