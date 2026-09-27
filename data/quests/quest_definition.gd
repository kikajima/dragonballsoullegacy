class_name QuestDefinition
extends Resource

@export var quest_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var objective_id: StringName = &""
@export var objective_text: String = ""
@export_range(1, 9999, 1) var target_count: int = 1
@export var reward_experience: int = 0
@export var reward_currency: int = 0
@export var reward_item_id: StringName = &""
@export var reward_item_amount: int = 0
