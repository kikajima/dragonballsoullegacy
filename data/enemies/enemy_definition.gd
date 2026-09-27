class_name EnemyDefinition
extends Resource

@export var enemy_id: StringName = &""
@export var display_name: String = ""
@export var ai_profile: EnemyAIProfile
@export var max_health: int = 30
@export var move_speed: float = 55.0
@export var melee_damage: int = 8
@export var detection_range: float = 170.0
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 0.55
@export var experience_reward: int = 25
