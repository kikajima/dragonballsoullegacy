class_name QuestManager
extends Node

# Quests and sagas (see QuestCatalog and QuestDefinition).
#
# Each quest holds a list of objectives (counters). When every objective is
# done the quest either completes on its own or, with a `turn_in` NPC, waits
# as "ready" until the player talks to that NPC. Completing a quest gives its
# rewards and starts the next quest of its saga.

signal quest_started(quest_id: StringName)
# progress/target_count sum all objectives of the quest.
signal quest_updated(
	quest_id: StringName,
	progress: int,
	target_count: int
)
signal quest_ready(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal saga_completed(saga_id: StringName)
signal tracked_changed(quest_id: StringName)
signal quests_restored

const STATUS_ACTIVE: String = "active"
const STATUS_READY: String = "ready"
const STATUS_COMPLETED: String = "completed"

# Old Kame Island quests (before the tutorial saga).
const LEGACY_TUTORIAL := ["training_basics", "roshi_ki_control", "roshi_special_training"]

# Starts the Kame Island tutorial on a new game.
@export var start_tutorial: bool = true

var _quests: Dictionary = {}
var _order: Array[String] = []
var _tracked: String = ""
var _position_check_left: float = 0.0
var _inventory: InventoryComponent

func _ready() -> void:
	if start_tutorial:
		call_deferred("_start_new_game")

func _start_new_game() -> void:
	if _quests.is_empty():
		start_quest_id(QuestCatalog.FIRST_QUEST)

func _process(delta: float) -> void:
	_bind_inventory()
	_position_check_left -= delta
	if _position_check_left > 0.0:
		return
	_position_check_left = 0.4
	_check_reach_objectives()

# --- Starting ----------------------------------------------------------------

func start_quest_id(quest_id: StringName) -> bool:
	return start_quest(QuestCatalog.get_definition(quest_id))

func start_quest(definition: QuestDefinition) -> bool:
	if definition == null or definition.quest_id == &"":
		return false

	var key := String(definition.quest_id)
	if _quests.has(key):
		return false

	_quests[key] = _make_state(definition)
	_order.erase(key)
	_order.append(key)

	# Story quests take over the tracker; side quests only when nothing else is.
	if definition.saga_id != &"" or not _is_trackable(_tracked):
		_tracked = key
		tracked_changed.emit(definition.quest_id)

	quest_started.emit(definition.quest_id)
	_refresh_collect_objectives()
	var summary := _summary(_quests[key])
	quest_updated.emit(definition.quest_id, summary.x, summary.y)
	return true

func _make_state(definition: QuestDefinition) -> Dictionary:
	var objectives: Array = []
	for objective: Dictionary in definition.get_objectives():
		var objective_state := {
			"id": String(objective.get("id", "")),
			"text": str(objective.get("text", "")),
			"progress": 0,
			"target": maxi(int(objective.get("target", 1)), 1),
		}
		for point_key in ["at", "marker"]:
			if objective.get(point_key) is Vector2:
				var point: Vector2 = objective[point_key]
				objective_state[point_key] = [point.x, point.y]
		if objective.has("radius"):
			objective_state["radius"] = float(objective["radius"])
		objectives.append(objective_state)

	var reward_items := {}
	for item_id in definition.reward_items:
		reward_items[String(item_id)] = int(definition.reward_items[item_id])

	var state := {
		"quest_id": String(definition.quest_id),
		"title": definition.title,
		"description": definition.description,
		"saga_id": String(definition.saga_id),
		"turn_in": String(definition.turn_in),
		"objectives": objectives,
		"status": STATUS_ACTIVE,
		"reward_experience": maxi(definition.reward_experience, 0),
		"reward_currency": maxi(definition.reward_currency, 0),
		"reward_item_id": String(definition.reward_item_id),
		"reward_item_amount": maxi(definition.reward_item_amount, 0),
		"reward_items": reward_items,
	}
	_sync_legacy_fields(state)
	return state

func start_simple_quest(
	quest_id: StringName,
	title: String,
	description: String,
	objective_id: StringName,
	objective_text: String,
	target_count: int,
	reward_experience: int = 0,
	reward_item_id: StringName = &"",
	reward_item_amount: int = 0,
	reward_currency: int = 0
) -> bool:
	var definition := QuestDefinition.new()
	definition.quest_id = quest_id
	definition.title = title
	definition.description = description
	definition.objective_id = objective_id
	definition.objective_text = objective_text
	definition.target_count = maxi(target_count, 1)
	definition.reward_experience = maxi(reward_experience, 0)
	definition.reward_currency = maxi(reward_currency, 0)
	definition.reward_item_id = reward_item_id
	definition.reward_item_amount = maxi(reward_item_amount, 0)
	return start_quest(definition)

# --- Progress ----------------------------------------------------------------

# Adds `amount` to every active objective with this id. Returns how many
# quests advanced.
func advance_objective(
	objective_id: StringName,
	amount: int = 1
) -> int:
	if objective_id == &"" or amount <= 0:
		return 0
	var key := String(objective_id)
	var advanced := 0
	for quest_key in _order.duplicate():
		var state: Dictionary = _quests.get(quest_key, {})
		if str(state.get("status", "")) != STATUS_ACTIVE:
			continue
		var changed := false
		for objective: Dictionary in state.get("objectives", []):
			if str(objective.get("id", "")) != key:
				continue
			var target := maxi(int(objective.get("target", 1)), 1)
			var progress := int(objective.get("progress", 0))
			if progress >= target:
				continue
			objective["progress"] = mini(progress + amount, target)
			changed = true
		if changed:
			advanced += 1
			_after_progress(StringName(quest_key))
	return advanced

func _after_progress(quest_id: StringName) -> void:
	var state: Dictionary = _quests.get(String(quest_id), {})
	_sync_legacy_fields(state)
	var summary := _summary(state)
	quest_updated.emit(quest_id, summary.x, summary.y)
	if not _all_done(state):
		return
	if str(state.get("turn_in", "")).is_empty():
		_complete_quest(quest_id)
	else:
		state["status"] = STATUS_READY
		quest_ready.emit(quest_id)

# "Collect" objectives follow what the bag holds.
func _refresh_collect_objectives() -> void:
	if _inventory == null:
		return
	for quest_key in _order.duplicate():
		var state: Dictionary = _quests.get(quest_key, {})
		var status := str(state.get("status", ""))
		if status != STATUS_ACTIVE and status != STATUS_READY:
			continue
		var changed := false
		for objective: Dictionary in state.get("objectives", []):
			var id := str(objective.get("id", ""))
			if not id.begins_with("collect:"):
				continue
			var held := _inventory.get_bag_quantity(StringName(id.substr(8)))
			var progress := mini(held, int(objective.get("target", 1)))
			if progress != int(objective.get("progress", 0)):
				objective["progress"] = progress
				changed = true
		if not changed:
			continue
		if status == STATUS_READY and not _all_done(state):
			state["status"] = STATUS_ACTIVE
			_sync_legacy_fields(state)
			var summary := _summary(state)
			quest_updated.emit(StringName(quest_key), summary.x, summary.y)
		elif status == STATUS_ACTIVE:
			_after_progress(StringName(quest_key))

func _check_reach_objectives() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or get_tree().get_first_node_in_group("open_world") == null:
		return
	var tile := player.global_position / 32.0
	for quest_key in _order.duplicate():
		var state: Dictionary = _quests.get(quest_key, {})
		if str(state.get("status", "")) != STATUS_ACTIVE:
			continue
		for objective: Dictionary in state.get("objectives", []):
			var id := str(objective.get("id", ""))
			if not id.begins_with("reach:") or not objective.get("at") is Array:
				continue
			var at := _point(objective["at"])
			if tile.distance_to(at) <= float(objective.get("radius", 8.0)):
				advance_objective(StringName(id), 1)

func _bind_inventory() -> void:
	if _inventory != null and is_instance_valid(_inventory):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_inventory = player.get_node_or_null("Components/InventoryComponent") as InventoryComponent
	if _inventory != null:
		_inventory.inventory_changed.connect(_refresh_collect_objectives)
		_refresh_collect_objectives()

# --- Turning in --------------------------------------------------------------

# Quests waiting to be reported to this NPC.
func get_ready_for(npc_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for quest_key in _order:
		var state: Dictionary = _quests[quest_key]
		if str(state.get("status", "")) == STATUS_READY and str(state.get("turn_in", "")) == String(npc_id):
			result.append(StringName(quest_key))
	return result

# Active quests to be reported to this NPC, not finished yet.
func get_pending_for(npc_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for quest_key in _order:
		var state: Dictionary = _quests[quest_key]
		if str(state.get("status", "")) == STATUS_ACTIVE and str(state.get("turn_in", "")) == String(npc_id):
			result.append(StringName(quest_key))
	return result

func turn_in(quest_id: StringName) -> bool:
	var state: Dictionary = _quests.get(String(quest_id), {})
	if str(state.get("status", "")) != STATUS_READY:
		return false
	# Collected items are handed over.
	if _inventory != null:
		for objective: Dictionary in state.get("objectives", []):
			var id := str(objective.get("id", ""))
			if id.begins_with("collect:"):
				_inventory.remove_item(StringName(id.substr(8)), int(objective.get("target", 1)))
	_complete_quest(quest_id)
	return true

# --- Queries -----------------------------------------------------------------

func is_active(quest_id: StringName) -> bool:
	var status := str(_quests.get(String(quest_id), {}).get("status", ""))
	return status == STATUS_ACTIVE or status == STATUS_READY

func is_ready(quest_id: StringName) -> bool:
	return str(_quests.get(String(quest_id), {}).get("status", "")) == STATUS_READY

func is_completed(quest_id: StringName) -> bool:
	return str(_quests.get(String(quest_id), {}).get("status", "")) == STATUS_COMPLETED

func is_started(quest_id: StringName) -> bool:
	return _quests.has(String(quest_id))

func get_quest(quest_id: StringName) -> Dictionary:
	var value: Variant = _quests.get(String(quest_id), {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

# Active and ready quests, oldest first.
func get_active_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_key in _order:
		var state: Dictionary = _quests[quest_key]
		var status := str(state.get("status", ""))
		if status == STATUS_ACTIVE or status == STATUS_READY:
			result.append(state.duplicate(true))
	return result

func get_completed_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_key in _order:
		var state: Dictionary = _quests[quest_key]
		if str(state.get("status", "")) == STATUS_COMPLETED:
			result.append(state.duplicate(true))
	return result

func get_all_quests() -> Dictionary:
	return _quests.duplicate(true)

# The quest shown in the HUD tracker.
func get_tracked_quest() -> Dictionary:
	if not _is_trackable(_tracked):
		_tracked = ""
		for quest_key in _order:
			if _is_trackable(quest_key):
				_tracked = quest_key
				if str(_quests[quest_key].get("saga_id", "")) != "":
					break
	return get_quest(StringName(_tracked)) if not _tracked.is_empty() else {}

func set_tracked(quest_id: StringName) -> void:
	if _is_trackable(String(quest_id)):
		_tracked = String(quest_id)
		tracked_changed.emit(quest_id)

# [done, total] quests of a saga, and whether it has started.
func get_saga_progress(saga_id: StringName) -> Dictionary:
	var saga := QuestCatalog.get_saga(saga_id)
	var done := 0
	var started := false
	var current := ""
	for quest_id: StringName in saga.get("quests", []):
		if is_completed(quest_id):
			done += 1
		if is_started(quest_id):
			started = true
		if is_active(quest_id):
			current = String(quest_id)
	var total: int = (saga.get("quests", []) as Array).size()
	return {"done": done, "total": total, "started": started,
		"completed": total > 0 and done == total, "current": current}

# Objective's map point (tile) for the tracker arrow, if any.
static func objective_point(objective: Dictionary) -> Variant:
	for point_key in ["at", "marker"]:
		if objective.get(point_key) is Array:
			return _point(objective[point_key])
	return null

# The first objective not finished yet.
static func current_objective(state: Dictionary) -> Dictionary:
	for objective: Dictionary in state.get("objectives", []):
		if int(objective.get("progress", 0)) < int(objective.get("target", 1)):
			return objective
	var objectives: Array = state.get("objectives", [])
	return objectives.back() if not objectives.is_empty() else {}

# --- Save --------------------------------------------------------------------

func serialize_state() -> Dictionary:
	return {
		"quests": _quests.duplicate(true),
		"order": _order.duplicate(),
		"tracked": _tracked,
	}

func load_state(data: Dictionary) -> void:
	_quests.clear()
	_order.clear()

	var quests_value: Variant = data.get("quests", {})
	if quests_value is Dictionary:
		_quests = (quests_value as Dictionary).duplicate(true)
	for quest_key in data.get("order", []):
		if _quests.has(str(quest_key)) and not _order.has(str(quest_key)):
			_order.append(str(quest_key))
	for quest_key in _quests.keys():
		if not _order.has(str(quest_key)):
			_order.append(str(quest_key))
	_tracked = str(data.get("tracked", ""))

	for quest_key in _quests.keys():
		_upgrade_state(_quests[quest_key])
	var started_tutorial := _upgrade_legacy_tutorial()

	quests_restored.emit()
	for quest_key in _order:
		var state: Dictionary = _quests[quest_key]
		var status := str(state.get("status", ""))
		if status == STATUS_ACTIVE or status == STATUS_READY:
			var summary := _summary(state)
			quest_updated.emit(StringName(quest_key), summary.x, summary.y)
	if started_tutorial != &"":
		start_quest_id(started_tutorial)
	_refresh_collect_objectives()

# Single-objective states (save version 7 and older) get an objective list.
func _upgrade_state(state: Dictionary) -> void:
	if state.get("objectives") is Array:
		# JSON reads every number back as a float.
		for objective: Dictionary in state["objectives"]:
			objective["progress"] = int(objective.get("progress", 0))
			objective["target"] = maxi(int(objective.get("target", 1)), 1)
		for key in ["reward_experience", "reward_currency", "reward_item_amount", "progress", "target_count"]:
			if state.has(key):
				state[key] = int(state[key])
		return
	state["objectives"] = [{
		"id": str(state.get("objective_id", "")),
		"text": str(state.get("objective_text", "")),
		"progress": int(state.get("progress", 0)),
		"target": maxi(int(state.get("target_count", 1)), 1),
	}]
	state["saga_id"] = str(state.get("saga_id", ""))
	state["turn_in"] = str(state.get("turn_in", ""))
	state["reward_items"] = state.get("reward_items", {})

# Saves from before the tutorial saga: a finished Roshi training skips the
# tutorial; an unfinished one starts it over. Returns the quest to start.
func _upgrade_legacy_tutorial() -> StringName:
	var legacy_done := str(_quests.get("roshi_special_training", {}).get("status", "")) == STATUS_COMPLETED
	for legacy in LEGACY_TUTORIAL:
		if _quests.has(legacy) and str(_quests[legacy].get("status", "")) != STATUS_COMPLETED:
			_quests.erase(legacy)
			_order.erase(legacy)
	if QuestCatalog.get_saga(&"kame_training").get("quests", []).any(
		func(quest_id: StringName) -> bool: return _quests.has(String(quest_id))
	):
		return &""
	if not legacy_done:
		return QuestCatalog.FIRST_QUEST
	for quest_id: StringName in QuestCatalog.get_saga(&"kame_training")["quests"]:
		if quest_id == &"kame_journey":
			break
		var state := _make_state(QuestCatalog.get_definition(quest_id))
		_quests[String(quest_id)] = state
		_order.append(String(quest_id))
		for objective: Dictionary in state["objectives"]:
			objective["progress"] = objective["target"]
		state["status"] = STATUS_COMPLETED
		_sync_legacy_fields(state)
	return &"kame_journey"

# --- Internals ---------------------------------------------------------------

func _complete_quest(quest_id: StringName) -> void:
	var key := String(quest_id)
	var state: Dictionary = _quests.get(key, {})
	var status := str(state.get("status", ""))
	if status != STATUS_ACTIVE and status != STATUS_READY:
		return

	state["status"] = STATUS_COMPLETED
	_sync_legacy_fields(state)
	if _tracked == key:
		_tracked = ""
	_apply_rewards(state)
	quest_completed.emit(quest_id)

	var saga_id := StringName(str(state.get("saga_id", "")))
	if saga_id != &"" and QuestCatalog.is_saga_finale(quest_id):
		saga_completed.emit(saga_id)

	var definition := QuestCatalog.get_definition(quest_id)
	if definition != null and definition.next_quest != &"":
		start_quest_id(definition.next_quest)
	elif _tracked.is_empty():
		tracked_changed.emit(StringName(str(get_tracked_quest().get("quest_id", ""))))

func _all_done(state: Dictionary) -> bool:
	for objective: Dictionary in state.get("objectives", []):
		if int(objective.get("progress", 0)) < int(objective.get("target", 1)):
			return false
	return true

func _summary(state: Dictionary) -> Vector2i:
	var progress := 0
	var target := 0
	for objective: Dictionary in state.get("objectives", []):
		progress += int(objective.get("progress", 0))
		target += maxi(int(objective.get("target", 1)), 1)
	return Vector2i(progress, maxi(target, 1))

# objective_text/progress/target_count mirror the current objective, for
# code that only knows single-objective quests.
func _sync_legacy_fields(state: Dictionary) -> void:
	var objective := current_objective(state)
	state["objective_id"] = str(objective.get("id", ""))
	state["objective_text"] = str(objective.get("text", ""))
	state["progress"] = int(objective.get("progress", 0))
	state["target_count"] = maxi(int(objective.get("target", 1)), 1)

func _is_trackable(quest_key: String) -> bool:
	if quest_key.is_empty() or not _quests.has(quest_key):
		return false
	var status := str(_quests[quest_key].get("status", ""))
	return status == STATUS_ACTIVE or status == STATUS_READY

static func _point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	var values: Array = value
	return Vector2(float(values[0]), float(values[1]))

func _apply_rewards(state: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var reward_experience: int = maxi(int(state.get("reward_experience", 0)), 0)
	if reward_experience > 0:
		var experience := player.get_node_or_null(
			"Components/ExperienceComponent"
		) as ExperienceComponent
		if experience != null:
			experience.add_experience(reward_experience)

	var reward_currency: int = maxi(int(state.get("reward_currency", 0)), 0)
	if reward_currency > 0:
		var wallet := player.get_node_or_null(
			"Components/WalletComponent"
		) as WalletComponent
		if wallet != null:
			wallet.add(reward_currency)

	var items := {}
	var reward_item_id := str(state.get("reward_item_id", ""))
	var reward_item_amount: int = maxi(int(state.get("reward_item_amount", 0)), 0)
	if not reward_item_id.is_empty() and reward_item_amount > 0:
		items[reward_item_id] = reward_item_amount
	var extra: Variant = state.get("reward_items", {})
	if extra is Dictionary:
		for item_id in extra:
			items[str(item_id)] = int(items.get(str(item_id), 0)) + int(extra[item_id])
	if items.is_empty():
		return
	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent
	if inventory == null:
		return
	for item_id in items:
		var amount: int = items[item_id]
		var added := inventory.add_item(StringName(item_id), amount)
		# A full bag drops the rest at the player's feet.
		if added < amount:
			_drop_at_player(player, StringName(item_id), amount - added)

func _drop_at_player(player: Node, item_id: StringName, amount: int) -> void:
	var scene := load("res://world/pickups/pickup_actor.tscn") as PackedScene
	var body := player as Node2D
	if scene == null or body == null or body.get_parent() == null:
		return
	var pickup := scene.instantiate() as PickupActor
	if pickup == null:
		return
	pickup.lifetime = 0.0
	body.get_parent().add_child(pickup)
	pickup.global_position = body.global_position + Vector2(0, 14)
	pickup.configure_item(item_id, amount)
