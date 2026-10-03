class_name QuestTracker
extends Control

@onready var title_label: Label = $Panel/Title
@onready var objective_label: Label = $Panel/Objective

var _quest_manager: QuestManager

func _ready() -> void:
	position = Vector2(292.0, 8.0)
	size = Vector2(178.0, 46.0)
	visible = false
	call_deferred("_bind_manager")

func _bind_manager() -> void:
	_quest_manager = get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if _quest_manager == null:
		return

	_quest_manager.quest_started.connect(_on_quest_changed)
	_quest_manager.quest_updated.connect(_on_quest_progress)
	_quest_manager.quest_completed.connect(_on_quest_changed)
	_quest_manager.quests_restored.connect(_refresh)
	_refresh()

func _on_quest_changed(_quest_id: StringName) -> void:
	_refresh()

func _on_quest_progress(
	_quest_id: StringName,
	_progress: int,
	_target_count: int
) -> void:
	_refresh()

func _refresh() -> void:
	if _quest_manager == null:
		visible = false
		return

	var active := _quest_manager.get_active_quests()
	if active.is_empty():
		visible = false
		return

	var state: Dictionary = active[0]
	title_label.text = str(state.get("title", "Quest"))

	var objective_text := str(
		state.get("objective_text", "Objective")
	)
	var progress: int = int(state.get("progress", 0))
	var target: int = maxi(
		int(state.get("target_count", 1)),
		1
	)

	objective_label.text = "%s  %d/%d" % [
		objective_text,
		progress,
		target
	]
	visible = true
