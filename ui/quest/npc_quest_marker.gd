class_name NpcQuestMarker
extends Node2D

# Floats over an NPC's head: "!" when the NPC has a quest to offer (or one
# of their quests is waiting to be told), "?" when a quest is ready to be
# reported to them.

var npc_id: StringName = &""
var _label: Label
var _quests: QuestManager
var _time := 0.0

static func attach(npc: Node2D, id: StringName, height: float = 34.0) -> NpcQuestMarker:
	var marker := NpcQuestMarker.new()
	marker.name = "QuestMarker"
	marker.npc_id = id
	marker.position = Vector2(0, -height)
	npc.add_child(marker)
	return marker

func _ready() -> void:
	z_index = 50
	_label = Label.new()
	_label.name = "Label"
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-8, -8)
	_label.size = Vector2(16, 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false
	call_deferred("_bind")

func _bind() -> void:
	_quests = get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if _quests == null:
		return
	for signal_name in ["quest_started", "quest_completed", "quest_ready"]:
		_quests.connect(signal_name, _refresh.unbind(1))
	_quests.quests_restored.connect(_refresh)
	_quests.quest_updated.connect(_refresh.unbind(3))
	_refresh()

func _process(delta: float) -> void:
	if visible:
		_time += delta
		_label.position.y = -8.0 + sin(_time * 4.0) * 1.5

func _refresh() -> void:
	if _quests == null or npc_id == &"":
		visible = false
		return
	var mark := ""
	if not _quests.get_ready_for(npc_id).is_empty():
		mark = "?"
	elif not QuestCatalog.offers_for(npc_id, _quests).is_empty() or _has_talk_objective():
		mark = "!"
	_label.text = mark
	visible = not mark.is_empty()

func _has_talk_objective() -> bool:
	var objective_id := "talk:%s" % npc_id
	for state in _quests.get_active_quests():
		for objective: Dictionary in state.get("objectives", []):
			if str(objective.get("id", "")) == objective_id and int(objective.get("progress", 0)) < int(objective.get("target", 1)):
				return true
	return false
