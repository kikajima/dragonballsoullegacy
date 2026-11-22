class_name CharacterStatsComponent
extends Node

# The five trained attributes. Each one has its own level (1..MAX_LEVEL) and
# grows only by doing what it represents (use-based training):
#
#   Strength      melee damage (punch, kick, sword) and extra bag spaces.
#                 Trains by landing melee hits.
#   Agility       walk/run/flight speed and the chance to dodge melee and
#                 ranged hits (zanzoken blink). Trains by running, dashing,
#                 flying fast and dash-dodging enemy shots.
#   Vigor         max HP and the gravity the body supports (up to 10,000x).
#                 Trains by spending time under gravity.
#   Wisdom        special/ki damage, special cooldowns and ki sense range.
#                 Trains by using ki techniques and meditating.
#   Intelligence  how much Analyze reveals and the chance to read enemy
#                 attacks. Trains by studying (library, university, lab).
#
# Effects are pure functions of the level so balance lives in one place.

signal stat_xp_changed(stat: StringName, xp: float, xp_to_next: float, level: int)
signal stat_leveled_up(stat: StringName, new_level: int)
signal stats_changed

const STRENGTH: StringName = &"strength"
const AGILITY: StringName = &"agility"
const VIGOR: StringName = &"vigor"
const WISDOM: StringName = &"wisdom"
const INTELLIGENCE: StringName = &"intelligence"
const STATS: Array[StringName] = [STRENGTH, AGILITY, VIGOR, WISDOM, INTELLIGENCE]
const STAT_NAMES := {
	&"strength": "Strength", &"agility": "Agility", &"vigor": "Vigor",
	&"wisdom": "Wisdom", &"intelligence": "Intelligence",
}

const MAX_LEVEL := 100
const MAX_GRAVITY := 10000.0

# XP needed to go from `level` to `level + 1`: 25 * level^1.5
# (25 at Lv 1, ~790 at Lv 10, ~8.8k at Lv 50, ~24.6k at Lv 99).
@export var xp_base: float = 25.0
@export var xp_exponent: float = 1.5

# Training rates (XP). Per-second rates are scaled by delta by the callers.
@export var xp_melee_hit: float = 4.0
@export var xp_run_per_second: float = 1.5
@export var xp_fast_flight_per_second: float = 2.5
@export var xp_dash: float = 3.0
@export var xp_dash_dodge: float = 25.0
@export var xp_evade: float = 6.0
@export var xp_special_per_ki: float = 0.6
@export var xp_ki_blast: float = 0.6
@export var xp_meditation_per_second: float = 4.0
@export var xp_gravity_per_second: float = 2.0
@export var xp_study_per_second: float = 5.0

@export var health_component_path: NodePath = ^"../HealthComponent"
@export var inventory_component_path: NodePath = ^"../InventoryComponent"

var _levels: Dictionary = {}
var _xp: Dictionary = {}
var _applied_health_bonus: int = 0

func _ready() -> void:
	for stat in STATS:
		_levels[stat] = 1
		_xp[stat] = 0.0
	_apply_derived.call_deferred()

static func stat_name(stat: StringName) -> String:
	return STAT_NAMES.get(stat, String(stat).capitalize())

func get_level(stat: StringName) -> int:
	return int(_levels.get(stat, 1))

func get_xp(stat: StringName) -> float:
	return float(_xp.get(stat, 0.0))

func xp_to_next(level: int) -> float:
	if level >= MAX_LEVEL:
		return 0.0
	return roundf(xp_base * pow(float(maxi(level, 1)), xp_exponent))

func get_progress(stat: StringName) -> float:
	var needed := xp_to_next(get_level(stat))
	return 1.0 if needed <= 0.0 else clampf(get_xp(stat) / needed, 0.0, 1.0)

# Adds training XP; returns the number of levels gained.
func add_xp(stat: StringName, amount: float) -> int:
	if not _levels.has(stat) or amount <= 0.0:
		return 0
	var level := get_level(stat)
	if level >= MAX_LEVEL:
		return 0
	var xp := get_xp(stat) + amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0.0
	_levels[stat] = level
	_xp[stat] = xp
	stat_xp_changed.emit(stat, xp, xp_to_next(level), level)
	if gained > 0:
		_apply_derived()
		stat_leveled_up.emit(stat, level)
		stats_changed.emit()
	return gained

func set_level(stat: StringName, level: int) -> void:
	if not _levels.has(stat):
		return
	_levels[stat] = clampi(level, 1, MAX_LEVEL)
	_xp[stat] = 0.0
	_apply_derived()
	stats_changed.emit()

# 0 at level 1, 1 at MAX_LEVEL.
func _t(stat: StringName) -> float:
	return float(get_level(stat) - 1) / float(MAX_LEVEL - 1)

# --- Strength --------------------------------------------------------------

func melee_damage_multiplier() -> float:
	return 1.0 + 0.02 * float(get_level(STRENGTH) - 1)

# One extra bag space every 10 levels (+10 at 100).
func carry_bonus_slots() -> int:
	return get_level(STRENGTH) / 10

# --- Agility -----------------------------------------------------------------

func move_speed_multiplier() -> float:
	return 1.0 + 0.006 * float(get_level(AGILITY) - 1)

# 2% at level 1 up to 40% at 100, against melee and ranged hits.
func dodge_chance() -> float:
	return lerpf(0.02, 0.40, _t(AGILITY))

# --- Vigor -------------------------------------------------------------------

func max_health_bonus() -> int:
	return 6 * (get_level(VIGOR) - 1)

# Gravity the body supports: 2x at level 1, 10,000x at 100 (exponential, so
# every level feels like the same step: ~9% more gravity per level).
func gravity_tolerance() -> float:
	return 2.0 * pow(MAX_GRAVITY / 2.0, _t(VIGOR))

# --- Wisdom --------------------------------------------------------------------

func magic_damage_multiplier() -> float:
	return 1.0 + 0.015 * float(get_level(WISDOM) - 1)

# Special cooldowns: x1.0 at level 1 down to x0.6 at 100.
func special_cooldown_multiplier() -> float:
	return lerpf(1.0, 0.6, _t(WISDOM))

# Radius (px) in which other beings' ki is felt; doubled while meditating.
func ki_sense_radius(meditating: bool = false) -> float:
	var radius := 140.0 + 6.0 * float(get_level(WISDOM) - 1)
	return radius * (2.0 if meditating else 1.0)

# --- Intelligence --------------------------------------------------------------

# 0: vague condition, 1: HP to 10%, 2: exact HP + power, 3: also attack
# and ki readings.
func analyze_tier() -> int:
	var level := get_level(INTELLIGENCE)
	if level >= 50:
		return 3
	if level >= 25:
		return 2
	if level >= 10:
		return 1
	return 0

# Chance to see an enemy attack coming ("!" warning): 5% .. 75%.
func attack_read_chance() -> float:
	return lerpf(0.05, 0.75, _t(INTELLIGENCE))

# --- Derived values --------------------------------------------------------------

func _apply_derived() -> void:
	var health := get_node_or_null(health_component_path) as HealthComponent
	if health != null:
		var wanted := max_health_bonus()
		var delta := wanted - _applied_health_bonus
		if delta > 0:
			health.increase_max_health(delta, true)
		elif delta < 0:
			health.max_health = maxi(health.max_health + delta, 1)
			health.current_health = mini(health.current_health, health.max_health)
			health.health_changed.emit(health.current_health, health.max_health)
		_applied_health_bonus = wanted
	var inventory := get_node_or_null(inventory_component_path) as InventoryComponent
	if inventory != null:
		inventory.set_bonus_capacity(carry_bonus_slots())

func serialize_state() -> Dictionary:
	var stats := {}
	for stat in STATS:
		stats[String(stat)] = {"level": get_level(stat), "xp": get_xp(stat)}
	# The saved max HP already includes this bonus.
	return {"stats": stats, "applied_health_bonus": _applied_health_bonus}

func load_state(data: Dictionary) -> void:
	var stats_value: Variant = data.get("stats", {})
	for stat in STATS:
		var entry: Variant = (stats_value as Dictionary).get(String(stat), {}) if stats_value is Dictionary else {}
		var entry_data: Dictionary = entry if entry is Dictionary else {}
		_levels[stat] = clampi(int(entry_data.get("level", 1)), 1, MAX_LEVEL)
		_xp[stat] = maxf(float(entry_data.get("xp", 0.0)), 0.0)
	_applied_health_bonus = maxi(int(data.get("applied_health_bonus", 0)), 0)
	_apply_derived()
	for stat in STATS:
		stat_xp_changed.emit(stat, get_xp(stat), xp_to_next(get_level(stat)), get_level(stat))
	stats_changed.emit()
