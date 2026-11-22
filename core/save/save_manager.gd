class_name SaveManager
extends Node

signal game_saved(path: String)
signal game_loaded(path: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_VERSION: int = 7

@export var save_path: String = "user://save_slot_01.json"

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_game() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		save_failed.emit("Player not found.")
		return false
	if player is Player and (player._respawning or player.health_component.is_dead()):
		save_failed.emit("Aguarde o retorno ao checkpoint antes de salvar.")
		return false

	var data := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"player": _serialize_player(player),
		"quests": _serialize_group_node("quest_manager"),
		"checkpoint": _serialize_group_node("checkpoint_manager"),
		"stats": _serialize_group_node("game_stats"),
		"training": _serialize_group_node("training_manager"),
		"world": _serialize_group_node("world_manager"),
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Could not open the save file for writing.")
		return false

	file.store_string(JSON.stringify(data, "	"))
	file.close()

	game_saved.emit(save_path)
	return true

func load_game() -> bool:
	if not has_save():
		load_failed.emit("No save found.")
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		load_failed.emit("Could not open the save file.")
		return false

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		load_failed.emit("Invalid or corrupted save.")
		return false

	var data: Dictionary = parsed as Dictionary
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		load_failed.emit(
			"Incompatible save version: %d." % version
		)
		return false

	if version < 6:
		upgrade_to_open_world(data)
	elif version == 6:
		upgrade_open_world_layout(data)

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		load_failed.emit("Player not found.")
		return false
	if player is Player and player._respawning:
		load_failed.emit("Aguarde o retorno ao checkpoint antes de carregar.")
		return false
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null and world.is_transitioning():
		load_failed.emit("Aguarde a troca de mapa antes de carregar.")
		return false

	# Same-map loads do not rebuild the world. Cancel unsaved combat state
	# before restoring resources; cancellation can emit cooldown notifications.
	if player is Player:
		player.reset_runtime_after_load()
	for group in [&"combat_projectile", &"active_special_beam"]:
		for effect in get_tree().get_nodes_in_group(group):
			effect.process_mode = Node.PROCESS_MODE_DISABLED
			effect.queue_free()

	# Restore the active world before restoring the player's position.
	_load_group_node_state(
		"world_manager",
		data.get("world", {})
	)

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
	_load_group_node_state(
		"game_stats",
		data.get("stats", {})
	)
	_load_group_node_state(
		"training_manager",
		data.get("training", {})
	)

	game_loaded.emit(save_path)
	return true

# Version 6 joined Kame Island, West City and the Rocky Wastes into one open
# world (OpenWorld). Older saves stored the map and positions in that map's
# own coordinates; move them to where that map now sits on Earth.
static func upgrade_to_open_world(data: Dictionary) -> void:
	var world_value: Variant = data.get("world", {})
	if world_value is Dictionary:
		var world_data := world_value as Dictionary
		var path := str(world_data.get("current_world_path", ""))
		if OpenWorld.LEGACY_OFFSETS.has(path):
			world_data["current_world_path"] = OpenWorld.SCENE_PATH
			var player_value: Variant = data.get("player", {})
			if player_value is Dictionary and (player_value as Dictionary).get("position") is Dictionary:
				var position_data := (player_value as Dictionary)["position"] as Dictionary
				var moved := OpenWorld.from_legacy(path, Vector2(
					float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0))
				))
				position_data["x"] = moved.x
				position_data["y"] = moved.y
	var checkpoint_value: Variant = data.get("checkpoint", {})
	if checkpoint_value is Dictionary:
		var checkpoint := checkpoint_value as Dictionary
		var path := str(checkpoint.get("world_path", ""))
		if OpenWorld.LEGACY_OFFSETS.has(path):
			var moved := OpenWorld.from_legacy(path, Vector2(
				float(checkpoint.get("position_x", 0.0)), float(checkpoint.get("position_y", 0.0))
			))
			checkpoint["world_path"] = OpenWorld.SCENE_PATH
			checkpoint["position_x"] = moved.x
			checkpoint["position_y"] = moved.y

# Version 7 rebuilt Earth from a full planet layout; the regions moved.
static func upgrade_open_world_layout(data: Dictionary) -> void:
	var world_value: Variant = data.get("world", {})
	if world_value is Dictionary and str((world_value as Dictionary).get("current_world_path", "")) == OpenWorld.SCENE_PATH:
		var player_value: Variant = data.get("player", {})
		if player_value is Dictionary and (player_value as Dictionary).get("position") is Dictionary:
			var position_data := (player_value as Dictionary)["position"] as Dictionary
			var moved := OpenWorld.from_v6(Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0))))
			position_data["x"] = moved.x
			position_data["y"] = moved.y
	var checkpoint_value: Variant = data.get("checkpoint", {})
	if checkpoint_value is Dictionary and str((checkpoint_value as Dictionary).get("world_path", "")) == OpenWorld.SCENE_PATH:
		var checkpoint := checkpoint_value as Dictionary
		var moved := OpenWorld.from_v6(Vector2(float(checkpoint.get("position_x", 0.0)), float(checkpoint.get("position_y", 0.0))))
		checkpoint["position_x"] = moved.x
		checkpoint["position_y"] = moved.y

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
		"equipment": {},
		"aura": {},
		"stats": {},
		"abilities": {},
		"wallet": {},
		"transformations": {},
		"combat": {},
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

	var equipment := player.get_node_or_null(
		"Components/EquipmentComponent"
	) as EquipmentComponent
	if equipment != null:
		result["equipment"] = equipment.serialize_state()

	var aura := player.get_node_or_null("Visuals/PowerAura") as PowerAuraComponent
	if aura != null:
		result["aura"] = aura.serialize_state()

	var stats := player.get_node_or_null("Components/CharacterStats") as CharacterStatsComponent
	if stats != null:
		result["stats"] = stats.serialize_state()

	var abilities := player.get_node_or_null(
		"Components/AbilityLoadoutComponent"
	) as AbilityLoadoutComponent
	if abilities != null:
		result["abilities"] = abilities.serialize_state()

	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as WalletComponent
	if wallet != null:
		result["wallet"] = wallet.serialize_state()

	var transformations := player.get_node_or_null(
		"Components/TransformationComponent"
	) as TransformationComponent
	if transformations != null:
		result["transformations"] = transformations.serialize_state()

	var melee := player.get_node_or_null(
		"Components/MeleeCombatComponent"
	) as MeleeCombatComponent
	var ki_blast := player.get_node_or_null(
		"Components/KiBlastComponent"
	) as KiBlastComponent
	if melee != null and ki_blast != null:
		result["combat"] = {
			"punch_damage": melee.damage,
			"kick_damage": melee.kick_damage,
			"ki_blast_damage": ki_blast.projectile_damage,
		}

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

	# After the inventory: equipped items must still be carried.
	var equipment := player.get_node_or_null(
		"Components/EquipmentComponent"
	) as EquipmentComponent
	var equipment_value: Variant = data.get("equipment", {})
	if equipment != null:
		equipment.load_state(
			equipment_value as Dictionary
			if equipment_value is Dictionary
			else {}
		)

	var aura := player.get_node_or_null("Visuals/PowerAura") as PowerAuraComponent
	var aura_value: Variant = data.get("aura", {})
	if aura != null:
		aura.load_state(aura_value as Dictionary if aura_value is Dictionary else {})

	# After health (the saved max HP already includes the Vigor bonus) and
	# the inventory (Strength sets extra bag spaces).
	var stats := player.get_node_or_null("Components/CharacterStats") as CharacterStatsComponent
	var stats_value: Variant = data.get("stats", {})
	if stats != null:
		stats.load_state(stats_value as Dictionary if stats_value is Dictionary else {})

	var abilities := player.get_node_or_null(
		"Components/AbilityLoadoutComponent"
	) as AbilityLoadoutComponent
	var abilities_value: Variant = data.get("abilities", {})
	if abilities != null and abilities_value is Dictionary:
		abilities.load_state(abilities_value as Dictionary)

	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as WalletComponent
	var wallet_value: Variant = data.get("wallet", {})
	if wallet != null and wallet_value is Dictionary:
		wallet.load_state(wallet_value as Dictionary)

	var transformations := player.get_node_or_null(
		"Components/TransformationComponent"
	) as TransformationComponent
	var transformations_value: Variant = data.get("transformations", {})
	if (
		transformations != null
		and transformations_value is Dictionary
	):
		transformations.load_state(
			transformations_value as Dictionary
		)

	var melee := player.get_node_or_null(
		"Components/MeleeCombatComponent"
	) as MeleeCombatComponent
	var ki_blast := player.get_node_or_null(
		"Components/KiBlastComponent"
	) as KiBlastComponent
	var combat_value: Variant = data.get("combat", {})
	if (
		melee != null
		and ki_blast != null
		and combat_value is Dictionary
	):
		var combat_data: Dictionary = combat_value as Dictionary
		melee.damage = maxi(
			int(combat_data.get("punch_damage", melee.damage)),
			1
		)
		melee.kick_damage = maxi(
			int(combat_data.get("kick_damage", melee.kick_damage)),
			1
		)
		ki_blast.projectile_damage = maxi(
			int(combat_data.get(
				"ki_blast_damage",
				ki_blast.projectile_damage
			)),
			1
		)

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
