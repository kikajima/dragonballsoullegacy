class_name HurtboxComponent
extends Area2D

signal hit_received(damage: int, source_position: Vector2)

@export var health_component_path: NodePath

@onready var health_component: HealthComponent = get_node(health_component_path) as HealthComponent

func receive_hit(damage: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if health_component == null:
		return

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
		return

	var applied_damage := health_component.take_damage(resolved_damage)
	if applied_damage <= 0:
		return

	hit_received.emit(applied_damage, source_position)
