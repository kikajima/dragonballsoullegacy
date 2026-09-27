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
			["O sistema de missões ainda não está disponível."],
			"Mentor"
		)
		return

	if quests.is_completed(TRAINING_QUEST_ID):
		dialogue.show_dialogue(
			[
				"Bom trabalho. Você já concluiu o treino básico.",
				"Quando tivermos novos inimigos, este sistema poderá encadear missões maiores."
			],
			"Mentor"
		)
		return

	if quests.is_active(TRAINING_QUEST_ID):
		var state := quests.get_quest(TRAINING_QUEST_ID)
		var progress: int = int(state.get("progress", 0))
		var target: int = int(state.get("target_count", 2))

		dialogue.show_dialogue(
			[
				"Continue o treino.",
				"Bonecos derrotados: %d/%d." % [progress, target]
			],
			"Mentor"
		)
		return

	quests.start_simple_quest(
		TRAINING_QUEST_ID,
		"Treino Básico",
		"Pratique o combate contra o adversário de treinamento.",
		TRAINING_OBJECTIVE_ID,
		"Derrote o adversário de treinamento",
		2,
		40,
		&"senzu_bean",
		1,
		100
	)

	dialogue.show_dialogue(
		[
			"Vamos testar sua evolução.",
			"Derrote o adversário de treinamento duas vezes.",
			"Como recompensa, você receberá XP extra e um Senzu Bean."
		],
		"Mentor"
	)
