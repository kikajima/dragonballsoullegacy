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

func interact(_actor: Node) -> void:
	var training := _get_training()
	if training == null:
		return

	if training.is_treadmill_active():
		training.stop_training()
		return

	training.start_treadmill(global_position)
	training.set_prompt("MOVE TO RUN")

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
