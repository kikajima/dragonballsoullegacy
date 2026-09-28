class_name AbilityLoadoutComponent
extends Node

signal ability_unlocked(ability_id: StringName)
signal ability_equipped(slot_index: int, ability_id: StringName)
signal cooldown_changed(ability_id: StringName, time_left: float)

@export_range(1, 12, 1)
var slot_count: int = 8

var _unlocked: Dictionary = {}
var _slots: Array[StringName] = []
var _cooldowns: Dictionary = {}

func _ready() -> void:
	_slots.resize(slot_count)
	for index in range(slot_count):
		_slots[index] = &""

func _process(delta: float) -> void:
	if _cooldowns.is_empty():
		return

	var finished: Array[String] = []

	for key in _cooldowns.keys():
		var time_left: float = maxf(float(_cooldowns[key]) - delta, 0.0)
		_cooldowns[key] = time_left
		cooldown_changed.emit(StringName(key), time_left)

		if time_left <= 0.0:
			finished.append(String(key))

	for key in finished:
		_cooldowns.erase(key)

func unlock_ability(ability_id: StringName) -> bool:
	if ability_id == &"":
		return false

	var key := String(ability_id)
	if bool(_unlocked.get(key, false)):
		return false

	_unlocked[key] = true
	ability_unlocked.emit(ability_id)
	return true

func is_unlocked(ability_id: StringName) -> bool:
	return bool(_unlocked.get(String(ability_id), false))

func equip_ability(slot_index: int, ability_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= _slots.size():
		return false

	if ability_id != &"" and not is_unlocked(ability_id):
		return false

	_slots[slot_index] = ability_id
	ability_equipped.emit(slot_index, ability_id)
	return true

func get_equipped_ability(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= _slots.size():
		return &""

	return _slots[slot_index]

func can_use(ability_id: StringName) -> bool:
	return (
		is_unlocked(ability_id)
		and get_cooldown_left(ability_id) <= 0.0
	)

func start_cooldown(ability_id: StringName, duration: float) -> void:
	if duration <= 0.0:
		_cooldowns.erase(String(ability_id))
		return

	_cooldowns[String(ability_id)] = duration
	cooldown_changed.emit(ability_id, duration)

func get_cooldown_left(ability_id: StringName) -> float:
	return float(_cooldowns.get(String(ability_id), 0.0))

func serialize_state() -> Dictionary:
	var unlocked_ids: Array[String] = []
	for key in _unlocked.keys():
		if bool(_unlocked[key]):
			unlocked_ids.append(String(key))

	var slot_ids: Array[String] = []
	for ability_id in _slots:
		slot_ids.append(String(ability_id))

	return {
		"unlocked": unlocked_ids,
		"slots": slot_ids,
	}

func load_state(data: Dictionary) -> void:
	_unlocked.clear()

	var unlocked_value: Variant = data.get("unlocked", [])
	if unlocked_value is Array:
		for value in unlocked_value as Array:
			unlock_ability(StringName(str(value)))

	_slots.clear()
	_slots.resize(slot_count)
	for index in range(slot_count):
		_slots[index] = &""

	var slots_value: Variant = data.get("slots", [])
	if slots_value is Array:
		var saved_slots: Array = slots_value as Array
		var count: int = mini(saved_slots.size(), slot_count)
		for index in range(count):
			var ability_id := StringName(str(saved_slots[index]))
			if ability_id == &"" or is_unlocked(ability_id):
				_slots[index] = ability_id
