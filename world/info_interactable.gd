class_name InfoInteractable
extends Area2D

@export var interaction_label: String = "Inspect"
@export var speaker: String = ""
@export_multiline var text: String = ""

func get_interaction_label() -> String:
	return interaction_label

func interact(_actor: Node) -> void:
	if text.is_empty():
		return

	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as DialogueBox
	if dialogue == null:
		return

	var pages: Array[String] = []
	for raw_page in text.split("|"):
		var page: String = String(raw_page).strip_edges()
		if not page.is_empty():
			pages.append(page)

	if pages.is_empty():
		return

	dialogue.show_dialogue(pages, speaker)
