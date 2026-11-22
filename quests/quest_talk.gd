class_name QuestTalk
extends RefCounted

# What happens when the player talks to an NPC that takes part in quests:
#   1. "talk:<npc>" objectives advance;
#   2. quests ready for this NPC are handed in (SagaDirector shows the
#      completion lines and the story of the next quest);
#   3. a side quest the NPC offers is started (SagaDirector shows its story);
#   4. a quest still to be reported here shows its progress;
#   5. otherwise the NPC's own lines.
# Returns true when quests drove the conversation.

static func talk(npc: Node, npc_id: StringName, speaker: String, fallback: Array) -> bool:
	var tree := npc.get_tree()
	var dialogue := tree.get_first_node_in_group("dialogue_ui") as DialogueBox
	var quests := tree.get_first_node_in_group("quest_manager") as QuestManager
	if quests == null or npc_id == &"":
		_show(dialogue, fallback, speaker)
		return false

	if quests.advance_objective(StringName("talk:%s" % npc_id)) > 0:
		_ensure_open(dialogue, ["..."], speaker)
		return true

	var ready := quests.get_ready_for(npc_id)
	if not ready.is_empty():
		quests.turn_in(ready[0])
		_ensure_open(dialogue, ["Well done."], speaker)
		return true

	var offers := QuestCatalog.offers_for(npc_id, quests)
	if not offers.is_empty():
		quests.start_quest_id(offers[0])
		_ensure_open(dialogue, ["I have a favour to ask."], speaker)
		return true

	var pending := quests.get_pending_for(npc_id)
	if not pending.is_empty():
		var state := quests.get_quest(pending[0])
		var lines: Array = ["%s:" % state.get("title", "Quest")]
		for objective: Dictionary in state.get("objectives", []):
			lines[0] += "\n%s  %d/%d" % [
				objective.get("text", ""), int(objective.get("progress", 0)),
				int(objective.get("target", 1)),
			]
		lines.append("Come back when you're done.")
		_show(dialogue, lines, speaker)
		return true

	_show(dialogue, fallback, speaker)
	return false

static func _show(dialogue: DialogueBox, lines: Array, speaker: String) -> void:
	if dialogue == null:
		return
	var pages: Array[String] = []
	for line in lines:
		if not str(line).strip_edges().is_empty():
			pages.append(str(line))
	if pages.is_empty():
		pages.append("...")
	dialogue.show_dialogue(pages, speaker)

# SagaDirector usually opened a dialogue already; if nothing had lines,
# answer something.
static func _ensure_open(dialogue: DialogueBox, lines: Array, speaker: String) -> void:
	if dialogue != null and not dialogue.is_open():
		_show(dialogue, lines, speaker)
