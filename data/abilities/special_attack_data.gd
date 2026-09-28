class_name SpecialAttackData
extends Resource

enum AttackType {
	PROJECTILE,
	CONTINUOUS_BEAM,
	SPREAD,
	ARC_GRENADE,
	CHARGED_PROJECTILE,
	MELEE,
	CHARGED_MELEE,
	FLURRY,
	AREA_STATUS,
	SWORD_WAVE,
	TRANSFORMATION,
}

enum CastPose {
	PROJECTILE,
	BEAM,
	MELEE,
	KICK,
	POSE,
	TRANSFORMATION,
}

@export var ability_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_enum(
	"Projectile",
	"Continuous Beam",
	"Spread",
	"Arc Grenade",
	"Charged Projectile",
	"Melee",
	"Charged Melee",
	"Flurry",
	"Area Status",
	"Sword Wave",
	"Transformation"
)
var attack_type: int = AttackType.PROJECTILE

@export_enum("Projectile", "Beam", "Melee", "Kick", "Pose", "Transformation")
var cast_pose: int = CastPose.PROJECTILE

@export var effect_key: StringName = &"blue_orb"

# Resource / timing.
@export var ki_cost: float = 10.0
@export var ki_drain_per_second: float = 0.0
@export var cooldown: float = 0.6
@export var damage: int = 18
@export var startup_duration: float = 0.18
@export var cast_lock_duration: float = 0.30

# Hold / charge behavior.
@export var charge_duration: float = 0.0
@export var charge_damage_multiplier: float = 1.0
@export var charge_range_multiplier: float = 1.0
@export var charge_scale_multiplier: float = 1.0

# Straight / charged projectile behavior.
@export var projectile_speed: float = 260.0
@export var projectile_scale: float = 1.0
@export var projectile_radius: float = 4.0
@export var projectile_range: float = 220.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 12.0

# Impact / explosion behavior.
@export var explosion_radius: float = 0.0
@export var screen_stun_on_impact: bool = false

# Arc/grenade behavior.
@export var arc_height: float = 20.0
@export var arc_duration: float = 0.55

# Beam behavior.
@export var beam_range: float = 190.0
@export var beam_width: float = 7.0
@export var beam_tick_interval: float = 0.16
@export var beam_pierces_targets: bool = false

# Melee behavior.
@export var melee_radius: float = 14.0
@export var melee_reach: float = 14.0
@export var melee_is_radial: bool = false
@export var dash_distance: float = 0.0

# Flurry behavior.
@export_range(1, 12, 1)
var flurry_hit_count: int = 1
@export_range(0, 6, 1)
var flurry_bonus_hit_limit: int = 0
@export var flurry_hit_interval: float = 0.12

# Status behavior.
@export var stun_duration: float = 0.0
@export var area_radius: float = 0.0

# Transformation behavior. The actual stat/drain definition lives in
# TransformationData; this keeps the special selector generic.
@export var transformation_id: StringName = &""

func is_charge_attack() -> bool:
	return charge_duration > 0.0

func is_continuous() -> bool:
	return attack_type == AttackType.CONTINUOUS_BEAM

func is_transformation() -> bool:
	return attack_type == AttackType.TRANSFORMATION

func get_cast_state() -> StringName:
	match cast_pose:
		CastPose.BEAM:
			return &"special_beam"
		CastPose.MELEE:
			return &"special_melee"
		CastPose.KICK:
			return &"special_kick"
		CastPose.POSE:
			return &"special_pose"
		CastPose.TRANSFORMATION:
			return &"special_transform"
		_:
			return &"special_projectile"
