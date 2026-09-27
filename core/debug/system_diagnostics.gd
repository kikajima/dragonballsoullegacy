class_name SystemDiagnostics
extends Node

func _ready() -> void:
	if not OS.is_debug_build():
		return

	call_deferred("_run_checks")

func _run_checks() -> void:
	var missing: Array[String] = []

	for group_name in [
		"player",
		"quest_manager",
		"save_manager",
		"checkpoint_manager",
		"world_manager",
		"dialogue_ui",
		"combat_feedback",
		"game_stats",
		"screen_transition",
	]:
		if get_tree().get_first_node_in_group(group_name) == null:
			missing.append("group:%s" % group_name)

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		for component_name in [
			"HealthComponent",
			"KiComponent",
			"ExperienceComponent",
			"InventoryComponent",
			"AbilityLoadoutComponent",
			"WalletComponent",
			"StatusEffectComponent",
			"TransformationComponent",
			"ComboTrackerComponent",
		]:
			if player.get_node_or_null(
				"Components/%s" % component_name
			) == null:
				missing.append(
					"player:%s" % component_name
				)

	if missing.is_empty():
		print(
			"DBSL diagnostics: core systems found."
		)
		return

	push_warning(
		"DBSL diagnostics: missing -> %s"
		% ", ".join(missing)
	)
