class_name HurtboxComponent
extends Area2D

signal hit_received(damage: int, source_position: Vector2)

@export var health_component_path: NodePath
@export var invulnerability_duration: float = 0.0

@onready var health_component: HealthComponent = get_node(health_component_path) as HealthComponent

var _invulnerability_left: float = 0.0

func _process(delta: float) -> void:
	_invulnerability_left = maxf(
		_invulnerability_left - delta,
		0.0
	)

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> int:
	if health_component == null or _invulnerability_left > 0.0:
		return 0

	var resolved_damage := damage
	var actor := get_parent()

	if actor != null and actor.has_method("modify_incoming_damage"):
		resolved_damage = int(
			actor.call(
				"modify_incoming_damage",
				damage,
				source_position
			)
		)

	if resolved_damage <= 0:
		return 0

	var applied_damage: int = health_component.take_damage(resolved_damage)
	if applied_damage <= 0:
		return 0

	if invulnerability_duration > 0.0:
		_invulnerability_left = invulnerability_duration

	hit_received.emit(applied_damage, source_position)
	return applied_damage
