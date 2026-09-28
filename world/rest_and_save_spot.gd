class_name RestAndSaveSpot
extends Area2D

@export var interaction_label: String = "Rest"

func get_interaction_label() -> String:
	return interaction_label

func interact(actor: Node) -> void:
	if actor == null:
		return

	var health := actor.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health != null:
		health.restore_full()

	var ki := actor.get_node_or_null(
		"Components/KiComponent"
	) as KiComponent
	if ki != null:
		ki.restore_full()

	var save_manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if save_manager != null:
		save_manager.save_game()

	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as DialogueBox
	if dialogue != null:
		dialogue.show_dialogue(
			[
				"You rest for a while.",
				"HP and Ki restored. Progress saved."
			],
			"Kame House"
		)
