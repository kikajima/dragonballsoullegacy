class_name MovementComponent
extends Node

@export var move_speed: float = 90.0

func move(body: CharacterBody2D, direction: Vector2, speed_scale: float = 1.0) -> void:
	var safe_direction := direction
	if safe_direction.length_squared() > 1.0:
		safe_direction = safe_direction.normalized()

	var safe_scale := maxf(speed_scale, 0.0)
	body.velocity = safe_direction * move_speed * safe_scale
	body.move_and_slide()

func stop(body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO
