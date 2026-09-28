class_name CheckpointManager
extends Node

signal checkpoint_changed(
	checkpoint_id: StringName,
	position: Vector2
)

var has_checkpoint: bool = false
var checkpoint_id: StringName = &""
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_world_path: String = ""

func set_checkpoint(
	new_checkpoint_id: StringName,
	position: Vector2
) -> void:
	has_checkpoint = true
	checkpoint_id = new_checkpoint_id
	checkpoint_position = position

	var world := get_tree().get_first_node_in_group(
		"world_manager"
	) as WorldManager
	checkpoint_world_path = (
		world.current_world_path
		if world != null
		else ""
	)

	checkpoint_changed.emit(checkpoint_id, checkpoint_position)

func clear_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_id = &""
	checkpoint_position = Vector2.ZERO
	checkpoint_world_path = ""

func get_respawn_position(fallback: Vector2) -> Vector2:
	return checkpoint_position if has_checkpoint else fallback

func get_checkpoint_world_path() -> String:
	return checkpoint_world_path

func serialize_state() -> Dictionary:
	return {
		"has_checkpoint": has_checkpoint,
		"checkpoint_id": String(checkpoint_id),
		"position_x": checkpoint_position.x,
		"position_y": checkpoint_position.y,
		"world_path": checkpoint_world_path,
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
	checkpoint_world_path = str(
		data.get("world_path", "")
	)

	if has_checkpoint:
		checkpoint_changed.emit(
			checkpoint_id,
			checkpoint_position
		)
