class_name KameHouseFridge
extends Area2D

const SENZU_ID: StringName = &"senzu_bean"
const STOCK_LIMIT: int = 2

func get_interaction_label() -> String:
	return "Check Fridge"

func interact(actor: Node) -> void:
	if actor == null:
		return

	var inventory := actor.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent
	if inventory == null:
		return

	var current: int = inventory.get_quantity(SENZU_ID)
	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as DialogueBox

	if current >= STOCK_LIMIT:
		if dialogue != null:
			dialogue.show_dialogue(
				[
					"There are no extra Senzu Beans to take right now.",
					"You already have enough emergency supplies."
				],
				"Kame House Fridge"
			)
		return

	var added: int = STOCK_LIMIT - current
	inventory.add_item(SENZU_ID, added)

	if dialogue != null:
		dialogue.show_dialogue(
			[
				"You take %d Senzu Bean%s from the fridge." % [
					added,
					"" if added == 1 else "s",
				],
				"Master Roshi keeps a small emergency stock here."
			],
			"Kame House Fridge"
		)
