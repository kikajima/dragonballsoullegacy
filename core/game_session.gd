class_name GameSession
extends Node

@export var autosave_on_quest_complete: bool = true

func _ready() -> void:
	call_deferred("_bind_session_events")

func _bind_session_events() -> void:
	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if quests != null:
		quests.quest_completed.connect(_on_quest_completed)

func _on_quest_completed(_quest_id: StringName) -> void:
	if not autosave_on_quest_complete:
		return

	var save_manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if save_manager != null:
		save_manager.call_deferred("save_game")
