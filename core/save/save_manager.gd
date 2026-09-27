class_name SaveManager
extends Node

signal game_saved(path: String)
signal game_loaded(path: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_VERSION: int = 2

@export var save_path: String = "user://save_slot_01.json"

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_game() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		save_failed.emit("Player não encontrado.")
		return false

	var data := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"player": _serialize_player(player),
		"quests": _serialize_group_node("quest_manager"),
		"checkpoint": _serialize_group_node("checkpoint_manager"),
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Não foi possível abrir o arquivo para escrita.")
		return false

	file.store_string(JSON.stringify(data, "	"))
	file.close()

	game_saved.emit(save_path)
	return true

func load_game() -> bool:
	if not has_save():
		load_failed.emit("Nenhum save encontrado.")
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		load_failed.emit("Não foi possível abrir o save.")
		return false

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		load_failed.emit("Save inválido ou corrompido.")
		return false

	var data: Dictionary = parsed as Dictionary
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		load_failed.emit(
			"Versão de save incompatível: %d." % version
		)
		return false

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		load_failed.emit("Player não encontrado.")
		return false

	var player_value: Variant = data.get("player", {})
	if player_value is Dictionary:
		_load_player(player, player_value as Dictionary)

	_load_group_node_state(
		"quest_manager",
		data.get("quests", {})
	)
	_load_group_node_state(
		"checkpoint_manager",
		data.get("checkpoint", {})
	)

	game_loaded.emit(save_path)
	return true

func delete_save() -> bool:
	if not has_save():
		return true

	var error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(save_path)
	)
	return error == OK

func _serialize_player(player: Node) -> Dictionary:
	var result := {
		"position": {
			"x": 0.0,
			"y": 0.0,
		},
		"health": {},
		"ki": {},
		"experience": {},
		"inventory": {},
		"abilities": {},
	}

	if player is Node2D:
		var node_2d := player as Node2D
		result["position"] = {
			"x": node_2d.global_position.x,
			"y": node_2d.global_position.y,
		}

	var health := player.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health != null:
		result["health"] = {
			"max": health.max_health,
			"current": health.current_health,
		}

	var ki := player.get_node_or_null(
		"Components/KiComponent"
	) as KiComponent
	if ki != null:
		result["ki"] = {
			"max": ki.max_ki,
			"current": ki.current_ki,
		}

	var experience := player.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent
	if experience != null:
		result["experience"] = {
			"level": experience.current_level,
			"current": experience.current_experience,
			"required": experience.experience_to_next_level,
		}

	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent
	if inventory != null:
		result["inventory"] = inventory.serialize_state()

	var abilities := player.get_node_or_null(
		"Components/AbilityLoadoutComponent"
	) as AbilityLoadoutComponent
	if abilities != null:
		result["abilities"] = abilities.serialize_state()

	return result

func _load_player(player: Node, data: Dictionary) -> void:
	var position_value: Variant = data.get("position", {})
	if player is Node2D and position_value is Dictionary:
		var position_data: Dictionary = position_value as Dictionary
		(player as Node2D).global_position = Vector2(
			float(position_data.get("x", 0.0)),
			float(position_data.get("y", 0.0))
		)

	var health := player.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	var health_value: Variant = data.get("health", {})
	if health != null and health_value is Dictionary:
		var health_data: Dictionary = health_value as Dictionary
		health.max_health = maxi(
			int(health_data.get("max", health.max_health)),
			1
		)
		health.current_health = clampi(
			int(health_data.get("current", health.max_health)),
			0,
			health.max_health
		)
		health.health_changed.emit(
			health.current_health,
			health.max_health
		)

	var ki := player.get_node_or_null(
		"Components/KiComponent"
	) as KiComponent
	var ki_value: Variant = data.get("ki", {})
	if ki != null and ki_value is Dictionary:
		var ki_data: Dictionary = ki_value as Dictionary
		ki.max_ki = maxf(
			float(ki_data.get("max", ki.max_ki)),
			1.0
		)
		ki.current_ki = clampf(
			float(ki_data.get("current", ki.max_ki)),
			0.0,
			ki.max_ki
		)
		ki.ki_changed.emit(
			ki.current_ki,
			ki.max_ki
		)

	var experience := player.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent
	var experience_value: Variant = data.get("experience", {})
	if experience != null and experience_value is Dictionary:
		var experience_data: Dictionary = experience_value as Dictionary
		experience.current_level = clampi(
			int(experience_data.get("level", 1)),
			1,
			experience.max_level
		)
		experience.current_experience = maxi(
			int(experience_data.get("current", 0)),
			0
		)
		experience.experience_to_next_level = maxi(
			int(experience_data.get("required", 1)),
			1
		)
		experience.experience_changed.emit(
			experience.current_experience,
			experience.experience_to_next_level,
			experience.current_level
		)

	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent
	var inventory_value: Variant = data.get("inventory", {})
	if inventory != null and inventory_value is Dictionary:
		inventory.load_state(inventory_value as Dictionary)

	var abilities := player.get_node_or_null(
		"Components/AbilityLoadoutComponent"
	) as AbilityLoadoutComponent
	var abilities_value: Variant = data.get("abilities", {})
	if abilities != null and abilities_value is Dictionary:
		abilities.load_state(abilities_value as Dictionary)

func _serialize_group_node(group_name: String) -> Dictionary:
	var node := get_tree().get_first_node_in_group(group_name)
	if node == null or not node.has_method("serialize_state"):
		return {}

	var value: Variant = node.call("serialize_state")
	if value is Dictionary:
		return value as Dictionary
	return {}

func _load_group_node_state(
	group_name: String,
	value: Variant
) -> void:
	if not value is Dictionary:
		return

	var node := get_tree().get_first_node_in_group(group_name)
	if node == null or not node.has_method("load_state"):
		return

	node.call("load_state", value as Dictionary)
