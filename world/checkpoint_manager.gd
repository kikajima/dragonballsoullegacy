class_name CheckpointManager
extends Node

signal checkpoint_changed(
	checkpoint_id: StringName,
	position: Vector2
)

var has_checkpoint: bool = false
var checkpoint_id: StringName = &""
var checkpoint_position: Vector2 = Vector2.ZERO

func set_checkpoint(
	new_checkpoint_id: StringName,
	position: Vector2
) -> void:
	has_checkpoint = true
	checkpoint_id = new_checkpoint_id
	checkpoint_position = position
	checkpoint_changed.emit(checkpoint_id, checkpoint_position)

func clear_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_id = &""
	checkpoint_position = Vector2.ZERO

func get_respawn_position(fallback: Vector2) -> Vector2:
	return checkpoint_position if has_checkpoint else fallback

func serialize_state() -> Dictionary:
	return {
		"has_checkpoint": has_checkpoint,
		"checkpoint_id": String(checkpoint_id),
		"position_x": checkpoint_position.x,
		"position_y": checkpoint_position.y,
	}

func load_state(data: Dictionary) -> void:
	has_checkpoint = bool(data.get("has_checkpoint", false))
	checkpoint_id = StringName(
		str(data.get("checkpoint_id", ""))
	)
	checkpoint_position = Vector2(
		float(data.get("position_x", 0.0)),
		float(data.get("position_y", 0.0))
	)

	if has_checkpoint:
		checkpoint_changed.emit(
			checkpoint_id,
			checkpoint_position
		)
