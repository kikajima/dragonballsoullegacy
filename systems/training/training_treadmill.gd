class_name TrainingTreadmill
extends Area2D

func get_interaction_label() -> String:
	var training := _get_training()
	if (
		training != null
		and training.is_treadmill_active()
	):
		return "Stop Treadmill"

	return "Start Treadmill"

func interact(actor: Node) -> void:
	var training := _get_training()
	if training == null:
		return

	if training.is_treadmill_active():
		training.stop_training()
		return

	# Keep the user at the accessible control position outside the solid base.
	if not actor is Node2D:
		return
	training.start_treadmill((actor as Node2D).global_position)
	training.set_prompt("MOVE TO RUN")

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
