class_name RecoveryStation
extends Area2D

@export var restore_health: bool = true
@export var restore_ki: bool = true

func get_interaction_label() -> String:
	return "Use Recovery Station"

func interact(actor: Node) -> void:
	if actor == null:
		return

	if restore_health:
		var health := actor.get_node_or_null(
			"Components/HealthComponent"
		) as HealthComponent
		if health != null:
			health.restore_full()

	if restore_ki:
		var ki := actor.get_node_or_null(
			"Components/KiComponent"
		) as KiComponent
		if ki != null:
			ki.restore_full()

	var training := get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
	if training != null:
		training.set_prompt("RECOVERED")
