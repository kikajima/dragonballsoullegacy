class_name SpecialAttackData
extends Resource

enum AttackType {
	PROJECTILE,
	BEAM,
	SPREAD,
}

enum CastPose {
	PROJECTILE,
	BEAM,
}

@export var ability_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_enum("Projectile", "Beam", "Spread")
var attack_type: int = AttackType.PROJECTILE

@export_enum("Projectile", "Beam")
var cast_pose: int = CastPose.PROJECTILE

@export var effect_key: StringName = &"blue_orb"

@export var ki_cost: float = 10.0
@export var cooldown: float = 0.6
@export var damage: int = 18
@export var startup_duration: float = 0.18
@export var cast_lock_duration: float = 0.30

@export var projectile_speed: float = 260.0
@export var projectile_scale: float = 1.0
@export var projectile_radius: float = 4.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 12.0

@export var beam_range: float = 190.0
@export var beam_width: float = 7.0
@export var beam_duration: float = 0.42

@export var stun_duration: float = 0.0
