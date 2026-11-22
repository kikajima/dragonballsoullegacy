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

const TRAINING_QUEST_ID: StringName = &"capsule_training_circuit"
const TRAINING_OBJECTIVE_ID: StringName = &"try_training_station"

# Up to 10,000x. How much of it the body takes depends on Vigor
# (CharacterStatsComponent.gravity_tolerance): under the tolerance the
# player is slowed less the stronger they are; above it they are crushed
# (very slow, losing HP every second).
const GRAVITY_LEVELS: Array[float] = [
	1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0,
	1000.0, 2000.0, 5000.0, 10000.0,
]
const MAX_GRAVITY := 10000.0
# Share of max HP lost per second for each "tolerance" of overload.
const OVERLOAD_DRAIN_PER_SECOND := 0.03
const OVERLOAD_DRAIN_CAP := 0.25

signal overload_changed(overloaded: bool)

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
var _overload_damage_credit: float = 0.0
var _overloaded: bool = false

func _ready() -> void:
	call_deferred("_bind_player")

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

# Time under gravity trains Vigor; past the tolerance it hurts.
func _process(delta: float) -> void:
	if gravity_multiplier <= 1.0 or get_tree().paused:
		_set_overloaded(false)
		return
	if _player == null or not is_instance_valid(_player):
		_bind_player()
	var stats := _get_stats()
	if stats == null:
		return
	var health := _player.get_node_or_null("Components/HealthComponent") as HealthComponent
	if health == null or health.is_dead():
		return
	var load := get_gravity_load()
	stats.add_xp(
		CharacterStatsComponent.VIGOR,
		stats.xp_gravity_per_second * (1.0 + 3.0 * minf(load, 1.5)) * delta
	)
	_set_overloaded(load > 1.0)
	if load <= 1.0:
		_overload_damage_credit = 0.0
		return
	var ratio := minf(OVERLOAD_DRAIN_PER_SECOND * (load - 1.0), OVERLOAD_DRAIN_CAP)
	_overload_damage_credit += float(health.max_health) * ratio * delta
	var damage := floori(_overload_damage_credit)
	if damage > 0:
		_overload_damage_credit -= damage
		health.take_damage(damage)

func _set_overloaded(value: bool) -> void:
	if value == _overloaded:
		return
	_overloaded = value
	overload_changed.emit(value)

func is_overloaded() -> bool:
	return _overloaded

# Current gravity / what the player's body supports (1.0 = at the limit).
func get_gravity_load() -> float:
	if gravity_multiplier <= 1.0:
		return 0.0
	var stats := _get_stats()
	var tolerance := stats.gravity_tolerance() if stats != null else 2.0
	return gravity_multiplier / maxf(tolerance, 1.0)

# "10,000x" style label for a gravity value.
static func format_gravity(value: float) -> String:
	var digits := str(roundi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return digits + grouped + "x"

func get_body_limit() -> float:
	var stats := _get_stats()
	return stats.gravity_tolerance() if stats != null else 2.0

func _get_stats() -> CharacterStatsComponent:
	if _player == null or not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("Components/CharacterStats") as CharacterStatsComponent

# Training XP grows with gravity, logarithmically past 10x so 10,000x stays
# rewarding without being absurd (10x -> 10, 100x -> 20, 10,000x -> 40).
func get_gravity_xp_factor() -> float:
	if gravity_multiplier <= 10.0:
		return maxf(gravity_multiplier, 1.0)
	return 10.0 * (1.0 + log(gravity_multiplier / 10.0) / log(10.0))

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
	_mark_mode_tried(mode)
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
	if gravity_multiplier > 1.0:
		_mark_mode_tried(MODE_GRAVITY)
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
			* get_gravity_xp_factor()
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
			* sqrt(get_gravity_xp_factor())
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
		* get_gravity_xp_factor()
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

# Within the tolerance the slowdown eases as the body adapts (x1.0 far below
# the limit, x0.55 at it); overloaded, the player can barely move.
func get_movement_multiplier() -> float:
	if gravity_multiplier <= 1.0:
		return 1.0
	var load := get_gravity_load()
	if load <= 1.0:
		return lerpf(1.0, 0.55, sqrt(load))
	return clampf(0.55 / load, 0.12, 0.55)

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
	# Session/anchor are not serialized; never resume a previous treadmill.
	stop_training()
	session_xp = 0
	gravity_multiplier = clampf(
		float(data.get("gravity_multiplier", 1.0)),
		1.0,
		MAX_GRAVITY
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

func _mark_mode_tried(mode: StringName) -> void:
	var key: String = String(mode)
	if modes_tried.has(key):
		return

	modes_tried[key] = true

	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if quests == null:
		return

	if (
		not quests.is_active(TRAINING_QUEST_ID)
		and not quests.is_completed(TRAINING_QUEST_ID)
	):
		quests.start_simple_quest(
			TRAINING_QUEST_ID,
			"Capsule Training Circuit",
			"Try every training system in the Capsule Corp chamber.",
			TRAINING_OBJECTIVE_ID,
			"Use a different training system",
			4,
			120,
			&"senzu_bean",
			1,
			250
		)

	quests.advance_objective(
		TRAINING_OBJECTIVE_ID,
		1
	)

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
