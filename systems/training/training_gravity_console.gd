class_name TrainingGravityConsole
extends Area2D

func get_interaction_label() -> String:
	var training := _get_training()
	if training == null:
		return "Gravity Console"

	return "Gravity %s -> next" % TrainingManager.format_gravity(training.gravity_multiplier)

func interact(_actor: Node) -> void:
	var training := _get_training()
	if training == null:
		return

	var value: float = training.cycle_gravity()
	var limit := training.get_body_limit()
	training.set_prompt(
		"GRAVITY %s  (BODY LIMIT %s)%s" % [
			TrainingManager.format_gravity(value),
			TrainingManager.format_gravity(limit),
			"  TOO HEAVY!" if value > limit else "",
		]
	)

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
