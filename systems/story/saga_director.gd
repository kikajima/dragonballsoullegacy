class_name SagaDirector
extends Node

# Runs the story side of quests:
#   - shows a quest's story when it starts and its closing lines when it is
#     completed, one dialogue after the other;
#   - keeps the bosses of active quests on the map (QuestDefinition.bosses);
#   - announces the start and the end of each saga.

const BOSS_META := &"saga_boss"
const BOSS_CHECK_INTERVAL := 1.0

var _queue: Array = [] # [[lines, speaker], ...]
var _boss_check_left: float = 0.0
var _quests: QuestManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("saga_director")
	call_deferred("_bind")

func _bind() -> void:
	_quests = get_tree().get_first_node_in_group("quest_manager") as QuestManager
	if _quests == null:
		return
	_quests.quest_started.connect(_on_quest_started)
	_quests.quest_completed.connect(_on_quest_completed)
	_quests.saga_completed.connect(_on_saga_completed)

func _process(delta: float) -> void:
	_show_next()
	if get_tree().paused:
		return
	_boss_check_left -= delta
	if _boss_check_left <= 0.0:
		_boss_check_left = BOSS_CHECK_INTERVAL
		update_bosses()

# --- Story -------------------------------------------------------------------

func _on_quest_started(quest_id: StringName) -> void:
	var definition := QuestCatalog.get_definition(quest_id)
	if definition == null:
		return
	var saga := QuestCatalog.get_saga(definition.saga_id)
	if not saga.is_empty() and (saga["quests"] as Array).front() == quest_id and quest_id != QuestCatalog.FIRST_QUEST:
		_notify("New saga: %s" % saga["title"])
	if not definition.story.is_empty():
		_enqueue(definition.story, definition.speaker)

func _on_quest_completed(quest_id: StringName) -> void:
	var definition := QuestCatalog.get_definition(quest_id)
	if definition != null and not definition.complete_text.is_empty():
		_enqueue(definition.complete_text, definition.complete_speaker)

func _on_saga_completed(saga_id: StringName) -> void:
	var saga := QuestCatalog.get_saga(saga_id)
	if not saga.is_empty():
		_notify("Saga complete: %s" % saga["title"])

func _enqueue(lines: PackedStringArray, speaker: String) -> void:
	_queue.append([lines, speaker])
	_show_next()

func has_pending_story() -> bool:
	return not _queue.is_empty()

func _show_next() -> void:
	if _queue.is_empty():
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue == null:
		_queue.clear()
		return
	# Wait for the current dialogue and for menus that pause the game.
	if dialogue.is_open() or get_tree().paused:
		return
	var entry: Array = _queue.pop_front()
	var pages: Array[String] = []
	for line in entry[0]:
		pages.append(str(line))
	dialogue.show_dialogue(pages, str(entry[1]))

func _notify(message: String) -> void:
	var feed := get_tree().get_first_node_in_group("notification_feed")
	if feed != null and feed.has_method("push_message"):
		feed.push_message(message)

# --- Bosses ------------------------------------------------------------------

func update_bosses() -> void:
	if _quests == null:
		return
	var world := get_tree().get_first_node_in_group("open_world") as OpenWorld
	var alive := get_tree().get_nodes_in_group("enemy").filter(
		func(node: Node) -> bool: return node.has_meta(BOSS_META)
	)
	# Bosses of quests that ended (or of another world) leave.
	var wanted := {}
	for state in _quests.get_active_quests():
		var definition := QuestCatalog.get_definition(StringName(str(state["quest_id"])))
		if definition != null and not definition.bosses.is_empty():
			wanted[String(definition.quest_id)] = [definition, state]
	for boss: Node in alive:
		var key := str(boss.get_meta(BOSS_META)).get_slice(":", 0)
		if not wanted.has(key) or world == null or not world.is_ancestor_of(boss):
			boss.queue_free()
	if world == null:
		return

	for quest_key in wanted:
		var definition: QuestDefinition = wanted[quest_key][0]
		var state: Dictionary = wanted[quest_key][1]
		for index in definition.bosses.size():
			var boss_entry: Dictionary = definition.bosses[index]
			var enemy_id: StringName = boss_entry.get("enemy", &"")
			var remaining := _remaining(state, enemy_id)
			var tag := "%s:%d" % [quest_key, index]
			var present := 0
			var already := false
			for boss: Node in alive:
				if not is_instance_valid(boss) or boss.is_queued_for_deletion():
					continue
				var boss_tag := str(boss.get_meta(BOSS_META))
				if boss_tag.get_slice(":", 0) == quest_key and boss.get("enemy_id") == enemy_id:
					present += 1
				if boss_tag == tag:
					already = true
			if already or present >= remaining:
				continue
			var boss := _spawn_boss(world, enemy_id, boss_entry.get("at", Vector2.ZERO), tag)
			if boss != null:
				alive.append(boss)

func _remaining(state: Dictionary, enemy_id: StringName) -> int:
	for objective: Dictionary in state.get("objectives", []):
		if str(objective.get("id", "")) == "defeat:%s" % enemy_id:
			return maxi(int(objective.get("target", 1)) - int(objective.get("progress", 0)), 0)
	return 0

func _spawn_boss(world: OpenWorld, enemy_id: StringName, tile: Vector2, tag: String) -> DebugGokuEnemy:
	var boss := EnemyCatalog.create(enemy_id)
	if boss == null:
		return null
	var point := (tile + Vector2(0.5, 0.5)) * OpenWorld.TILE
	if not world.is_landable_point(point):
		point = world.nearest_land_point(point)
	boss.set_meta(BOSS_META, tag)
	boss.position = world.to_local(point)
	boss.initial_facing = "down"
	world.add_child(boss)
	return boss
