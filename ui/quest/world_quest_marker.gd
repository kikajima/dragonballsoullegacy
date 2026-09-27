class_name WorldQuestMarker
extends Node2D

@export var quest_id: StringName = &""

@onready var label: Label = $Label

var _quest_manager: QuestManager

func _ready() -> void:
	call_deferred("_bind_quest_manager")

func _bind_quest_manager() -> void:
	_quest_manager = get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if _quest_manager == null:
		visible = false
		return

	_quest_manager.quest_started.connect(_on_quest_changed)
	_quest_manager.quest_updated.connect(_on_quest_updated)
	_quest_manager.quest_completed.connect(_on_quest_changed)
	_quest_manager.quests_restored.connect(_refresh)
	_refresh()

func _on_quest_changed(_changed_id: StringName) -> void:
	_refresh()

func _on_quest_updated(
	_changed_id: StringName,
	_progress: int,
	_target: int
) -> void:
	_refresh()

func _refresh() -> void:
	if _quest_manager == null or quest_id == &"":
		visible = false
		return

	if _quest_manager.is_completed(quest_id):
		visible = false
		return

	if _quest_manager.is_active(quest_id):
		label.text = "?"
		visible = true
		return

	label.text = "!"
	visible = true
