class_name LevelStatsComponent
extends Node

@export var experience_component_path: NodePath
@export var health_component_path: NodePath
@export var ki_component_path: NodePath
@export var melee_component_path: NodePath
@export var ki_blast_component_path: NodePath

@export var health_per_level: int = 10
@export var ki_per_level: float = 5.0
@export var punch_damage_per_level: int = 1
@export var kick_damage_per_level: int = 1
@export var ki_blast_damage_per_level: int = 1

@onready var experience_component: ExperienceComponent = (
	get_node(experience_component_path) as ExperienceComponent
)
@onready var health_component: HealthComponent = (
	get_node(health_component_path) as HealthComponent
)
@onready var ki_component: KiComponent = (
	get_node(ki_component_path) as KiComponent
)
@onready var melee_component: MeleeCombatComponent = (
	get_node(melee_component_path) as MeleeCombatComponent
)
@onready var ki_blast_component: KiBlastComponent = (
	get_node(ki_blast_component_path) as KiBlastComponent
)

func _ready() -> void:
	experience_component.leveled_up.connect(_on_leveled_up)

func _on_leveled_up(new_level: int) -> void:
	health_component.increase_max_health(health_per_level, true)
	ki_component.increase_max_ki(ki_per_level, true)

	melee_component.damage += punch_damage_per_level
	melee_component.kick_damage += kick_damage_per_level
	ki_blast_component.projectile_damage += ki_blast_damage_per_level

	print(
		"LEVEL UP! Nível %d | HP %d | Ki %.0f | Soco %d | Chute %d | Ki Blast %d"
		% [
			new_level,
			health_component.max_health,
			ki_component.max_ki,
			melee_component.damage,
			melee_component.kick_damage,
			ki_blast_component.projectile_damage,
		]
	)
