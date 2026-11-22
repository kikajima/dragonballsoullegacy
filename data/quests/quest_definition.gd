class_name QuestDefinition
extends Resource

# One quest. Most quests are defined in QuestCatalog; this resource is what
# QuestManager.start_quest() takes.
#
# Objectives are generic counters advanced by QuestManager.advance_objective():
#   "talk:<npc>"       talking to that NPC
#   "defeat:<enemy>"   defeating that enemy ("defeat:wild" any wild fighter)
#   "hit:punch"...     tutorial actions (also "block", "ki_blast", "fly",
#                      "charge_ki_second", "use_special_attack",
#                      "open_inventory", "rest", "craft", "dragon_ball")
#   "reach:<place>"    standing within `radius` tiles of `at` (a tile)
#   "collect:<item>"   holding that many of the item (taken on turn-in)

@export var quest_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""

# Single objective (older quests). Ignored when `objectives` is not empty.
@export var objective_id: StringName = &""
@export var objective_text: String = ""
@export_range(1, 9999, 1) var target_count: int = 1

# [{id, text, target, at?: Vector2 tile, radius?: tiles, marker?: Vector2 tile}]
@export var objectives: Array[Dictionary] = []

@export var saga_id: StringName = &""
# NPC that offers the quest when talked to (none: started by the story).
@export var giver: StringName = &""
# NPC to report back to; with none the quest completes on its own.
@export var turn_in: StringName = &""
# Quest started as soon as this one is completed.
@export var next_quest: StringName = &""
@export var requires: Array[StringName] = []
# Shown when the quest starts / is completed.
@export var speaker: String = ""
@export var story: PackedStringArray = PackedStringArray()
@export var complete_speaker: String = ""
@export var complete_text: PackedStringArray = PackedStringArray()
# Bosses that appear while the quest is active: [{enemy, at: Vector2 tile}].
@export var bosses: Array[Dictionary] = []

@export var reward_experience: int = 0
@export var reward_currency: int = 0
@export var reward_item_id: StringName = &""
@export var reward_item_amount: int = 0
# item_id -> amount, on top of reward_item_id.
@export var reward_items: Dictionary = {}

func get_objectives() -> Array[Dictionary]:
	if not objectives.is_empty():
		return objectives
	var single: Array[Dictionary] = [{
		"id": objective_id,
		"text": objective_text,
		"target": maxi(target_count, 1),
	}]
	return single
