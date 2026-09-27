class_name QuestManager
extends Node

signal quest_started(quest_id: StringName)
signal quest_updated(
	quest_id: StringName,
	progress: int,
	target_count: int
)
signal quest_completed(quest_id: StringName)
signal quests_restored

const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"

var _quests: Dictionary = {}

func start_quest(definition: QuestDefinition) -> bool:
	if definition == null or definition.quest_id == &"":
		return false

	var key := String(definition.quest_id)
	if _quests.has(key):
		return false

	_quests[key] = {
		"quest_id": key,
		"title": definition.title,
		"description": definition.description,
		"objective_id": String(definition.objective_id),
		"objective_text": definition.objective_text,
		"target_count": maxi(definition.target_count, 1),
		"progress": 0,
		"status": STATUS_ACTIVE,
		"reward_experience": maxi(definition.reward_experience, 0),
		"reward_item_id": String(definition.reward_item_id),
		"reward_item_amount": maxi(definition.reward_item_amount, 0),
	}

	quest_started.emit(definition.quest_id)
	quest_updated.emit(
		definition.quest_id,
		0,
		maxi(definition.target_count, 1)
	)
	return true

func start_simple_quest(
	quest_id: StringName,
	title: String,
	description: String,
	objective_id: StringName,
	objective_text: String,
	target_count: int,
	reward_experience: int = 0,
	reward_item_id: StringName = &"",
	reward_item_amount: int = 0
) -> bool:
	var definition := QuestDefinition.new()
	definition.quest_id = quest_id
	definition.title = title
	definition.description = description
	definition.objective_id = objective_id
	definition.objective_text = objective_text
	definition.target_count = maxi(target_count, 1)
	definition.reward_experience = maxi(reward_experience, 0)
	definition.reward_item_id = reward_item_id
	definition.reward_item_amount = maxi(reward_item_amount, 0)
	return start_quest(definition)

func advance_objective(
	objective_id: StringName,
	amount: int = 1
) -> int:
	if objective_id == &"" or amount <= 0:
		return 0

	var advanced_count: int = 0
	var objective_key := String(objective_id)

	for quest_key in _quests.keys():
		var state_value: Variant = _quests[quest_key]
		if not state_value is Dictionary:
			continue

		var state: Dictionary = state_value as Dictionary
		if str(state.get("status", "")) != STATUS_ACTIVE:
			continue

		if str(state.get("objective_id", "")) != objective_key:
			continue

		var target_count: int = maxi(
			int(state.get("target_count", 1)),
			1
		)
		var progress: int = int(state.get("progress", 0))
		progress = mini(progress + amount, target_count)
		state["progress"] = progress
		_quests[quest_key] = state

		var quest_id := StringName(str(quest_key))
		quest_updated.emit(quest_id, progress, target_count)
		advanced_count += 1

		if progress >= target_count:
			_complete_quest(quest_id)

	return advanced_count

func is_active(quest_id: StringName) -> bool:
	var state := get_quest(quest_id)
	return str(state.get("status", "")) == STATUS_ACTIVE

func is_completed(quest_id: StringName) -> bool:
	var state := get_quest(quest_id)
	return str(state.get("status", "")) == STATUS_COMPLETED

func get_quest(quest_id: StringName) -> Dictionary:
	var value: Variant = _quests.get(String(quest_id), {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func get_active_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for quest_key in _quests.keys():
		var value: Variant = _quests[quest_key]
		if not value is Dictionary:
			continue

		var state: Dictionary = value as Dictionary
		if str(state.get("status", "")) == STATUS_ACTIVE:
			result.append(state.duplicate(true))

	return result

func get_all_quests() -> Dictionary:
	return _quests.duplicate(true)

func serialize_state() -> Dictionary:
	return {
		"quests": _quests.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	_quests.clear()

	var quests_value: Variant = data.get("quests", {})
	if quests_value is Dictionary:
		_quests = (quests_value as Dictionary).duplicate(true)

	quests_restored.emit()

	for state_value in _quests.values():
		if not state_value is Dictionary:
			continue

		var state: Dictionary = state_value as Dictionary
		if str(state.get("status", "")) != STATUS_ACTIVE:
			continue

		quest_updated.emit(
			StringName(str(state.get("quest_id", ""))),
			int(state.get("progress", 0)),
			maxi(int(state.get("target_count", 1)), 1)
		)

func _complete_quest(quest_id: StringName) -> void:
	var key := String(quest_id)
	var value: Variant = _quests.get(key, {})
	if not value is Dictionary:
		return

	var state: Dictionary = value as Dictionary
	if str(state.get("status", "")) != STATUS_ACTIVE:
		return

	state["status"] = STATUS_COMPLETED
	_quests[key] = state

	_apply_rewards(state)
	quest_completed.emit(quest_id)

func _apply_rewards(state: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var reward_experience: int = maxi(
		int(state.get("reward_experience", 0)),
		0
	)
	if reward_experience > 0:
		var experience := player.get_node_or_null(
			"Components/ExperienceComponent"
		) as ExperienceComponent
		if experience != null:
			experience.add_experience(reward_experience)

	var reward_item_id := StringName(
		str(state.get("reward_item_id", ""))
	)
	var reward_item_amount: int = maxi(
		int(state.get("reward_item_amount", 0)),
		0
	)
	if reward_item_id != &"" and reward_item_amount > 0:
		var inventory := player.get_node_or_null(
			"Components/InventoryComponent"
		) as InventoryComponent
		if inventory != null:
			inventory.add_item(
				reward_item_id,
				reward_item_amount
			)
