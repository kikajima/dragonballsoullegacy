class_name FacingComponent
extends Node

signal facing_changed(facing: StringName)

@export_enum("up", "down", "left", "right")
var initial_facing: String = "down"

var current_facing: StringName = &"down"

func _ready() -> void:
	current_facing = StringName(initial_facing)

func update_from_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	var next_facing := current_facing

	if absf(direction.x) > absf(direction.y):
		next_facing = &"right" if direction.x > 0.0 else &"left"
	else:
		next_facing = &"down" if direction.y > 0.0 else &"up"

	if next_facing == current_facing:
		return

	current_facing = next_facing
	facing_changed.emit(current_facing)
