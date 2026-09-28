class_name TrainingGravityConsole
extends Area2D

func get_interaction_label() -> String:
	var training := _get_training()
	if training == null:
		return "Gravity Console"

	return "Gravity %.0fx -> next" % training.gravity_multiplier

func interact(_actor: Node) -> void:
	var training := _get_training()
	if training == null:
		return

	var value: float = training.cycle_gravity()
	training.set_prompt(
		"GRAVITY %.0fx" % value
	)

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
