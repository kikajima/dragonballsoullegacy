class_name KnockbackComponent
extends Node

@export var strength: float = 115.0
@export var duration: float = 0.16

var _active: bool = false
var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.ZERO

func start(body: CharacterBody2D, source_position: Vector2) -> void:
	_direction = body.global_position - source_position

	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	else:
		_direction = _direction.normalized()

	_elapsed = 0.0
	_active = true

func tick(body: CharacterBody2D, delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	var progress := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var current_speed := lerpf(strength, 0.0, progress)

	body.velocity = _direction * current_speed
	body.move_and_slide()

	if _elapsed >= duration:
		stop(body)

func stop(body: CharacterBody2D) -> void:
	_active = false
	_elapsed = 0.0
	body.velocity = Vector2.ZERO

func is_active() -> bool:
	return _active
