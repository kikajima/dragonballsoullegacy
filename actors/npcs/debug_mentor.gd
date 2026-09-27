class_name DebugMentor
extends Node2D

const TRAINING_QUEST_ID: StringName = &"training_basics"
const TRAINING_OBJECTIVE_ID: StringName = &"defeat_training_dummy"

func interact(_actor: Node) -> void:
	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as DialogueBox
	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager

	if dialogue == null:
		return

	if quests == null:
		dialogue.show_dialogue(
			["The quest system is not available yet."],
			"Master"
		)
		return

	if quests.is_completed(TRAINING_QUEST_ID):
		dialogue.show_dialogue(
			[
				"Good work. You already completed the basic training.",
				"Once we add more enemies, this system can chain larger quests."
			],
			"Master"
		)
		return

	if quests.is_active(TRAINING_QUEST_ID):
		var state := quests.get_quest(TRAINING_QUEST_ID)
		var progress: int = int(state.get("progress", 0))
		var target: int = int(state.get("target_count", 2))

		dialogue.show_dialogue(
			[
				"Keep training.",
				"Training opponents defeated: %d/%d." % [progress, target]
			],
			"Master"
		)
		return

	quests.start_simple_quest(
		TRAINING_QUEST_ID,
		"Basic Training",
		"Practice combat against the training opponent.",
		TRAINING_OBJECTIVE_ID,
		"Defeat the training opponent",
		2,
		40,
		&"senzu_bean",
		1,
		100
	)

	dialogue.show_dialogue(
		[
			"Let us test your progress.",
			"Defeat the training opponent twice.",
			"As a reward, you will receive extra XP, Zeni, and a Senzu Bean."
		],
		"Master"
	)
