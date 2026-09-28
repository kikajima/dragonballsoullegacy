class_name WorldPortal
extends Area2D

@export_file("*.tscn")
var target_scene: String = ""
@export var target_spawn: Vector2 = Vector2.ZERO
@export var interaction_label: String = "Travel"
@export var reset_training_environment: bool = true

var _transitioning: bool = false

func get_interaction_label() -> String:
	return interaction_label

func interact(_actor: Node) -> void:
	if _transitioning or target_scene.is_empty():
		return

	_transitioning = true
	call_deferred("_travel")

func _travel() -> void:
	if reset_training_environment:
		var training := get_tree().get_first_node_in_group(
			"training_manager"
		) as TrainingManager
		if training != null:
			training.reset_training_environment()

	var world := get_tree().get_first_node_in_group(
		"world_manager"
	) as WorldManager
	if world != null:
		# WorldManager owns the async transition. This portal is part of the
		# outgoing world and may be freed before fade-in completes.
		world.load_world_with_transition(
			target_scene,
			target_spawn,
			true
		)
