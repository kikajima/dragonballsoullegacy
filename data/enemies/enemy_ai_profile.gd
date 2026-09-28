class_name EnemyAIProfile
extends Resource

enum IntelligenceTier {
	COMMON,
	UNCOMMON,
	ELITE,
	BOSS,
}

@export_enum("Common", "Uncommon", "Elite", "Boss")
var intelligence_tier: int = IntelligenceTier.COMMON

@export_range(0.05, 1.0, 0.01)
var reaction_time: float = 0.42

@export_range(0.0, 1.0, 0.01)
var melee_block_chance: float = 0.12

@export_range(0.0, 1.0, 0.01)
var ranged_block_chance: float = 0.18

@export_range(0.0, 1.0, 0.01)
var projectile_dodge_chance: float = 0.06

@export_range(32.0, 320.0, 1.0)
var projectile_scan_range: float = 110.0

@export_range(24.0, 240.0, 1.0)
var dodge_min_distance: float = 90.0

@export_range(0.1, 1.5, 0.01)
var guard_duration: float = 0.32

@export_range(0.1, 1.0, 0.01)
var dodge_duration: float = 0.18

@export_range(1.0, 3.0, 0.05)
var dodge_speed_scale: float = 1.20

@export_range(0.0, 1.0, 0.01)
var counterattack_chance: float = 0.05

@export_range(0.0, 1.0, 0.01)
var strafe_chance: float = 0.03

@export_range(0.0, 1.0, 0.01)
var ranged_attack_chance: float = 0.15

@export_range(0.5, 2.0, 0.05)
var ranged_cooldown_scale: float = 1.0

@export_range(0.0, 1.5, 0.05)
var strafe_weight: float = 0.25

@export_range(0.5, 10.0, 0.05)
var health_multiplier: float = 1.0

@export_range(0.5, 5.0, 0.05)
var damage_multiplier: float = 1.0

@export_range(0.5, 2.0, 0.05)
var move_speed_multiplier: float = 1.0

@export_range(0.5, 10.0, 0.05)
var experience_multiplier: float = 1.0

@export_range(0.5, 5.0, 0.05)
var loot_multiplier: float = 1.0

func get_tier_name() -> String:
	match intelligence_tier:
		IntelligenceTier.UNCOMMON:
			return "Uncommon"
		IntelligenceTier.ELITE:
			return "Elite"
		IntelligenceTier.BOSS:
			return "Boss"
		_:
			return "Common"
