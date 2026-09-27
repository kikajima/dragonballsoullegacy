class_name PauseMenu
extends Control

@onready var resume_button: Button = $Panel/ResumeButton
@onready var save_button: Button = $Panel/SaveButton
@onready var load_button: Button = $Panel/LoadButton
@onready var status_label: Label = $Panel/Status

@onready var level_label: Label = $Panel/Stats/Level
@onready var xp_label: Label = $Panel/Stats/XP
@onready var hp_label: Label = $Panel/Stats/HP
@onready var ki_label: Label = $Panel/Stats/Ki
@onready var zeni_label: Label = $Panel/Stats/Zeni
@onready var senzu_label: Label = $Panel/Stats/Senzu
@onready var kos_label: Label = $Panel/Stats/KOs
@onready var time_label: Label = $Panel/Stats/Time
@onready var quest_title_label: Label = $Panel/Quest/Title
@onready var quest_objective_label: Label = $Panel/Quest/Objective

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_resume)
	save_button.pressed.connect(_save)
	load_button.pressed.connect(_load)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	var dialogue := get_tree().get_first_node_in_group(
		"dialogue_ui"
	) as Control
	if dialogue != null and dialogue.visible:
		return

	if visible:
		_resume()
	else:
		_pause()

	get_viewport().set_input_as_handled()

func _pause() -> void:
	visible = true
	status_label.text = ""
	_refresh_status()
	get_tree().paused = true
	resume_button.grab_focus()

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _save() -> void:
	var manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if manager == null:
		status_label.text = "SaveManager not found."
		return

	status_label.text = (
		"Game saved."
		if manager.save_game()
		else "Failed to save."
	)

func _load() -> void:
	var manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if manager == null:
		status_label.text = "SaveManager not found."
		return

	var loaded: bool = manager.load_game()
	status_label.text = (
		"Save loaded."
		if loaded
		else "No valid save found."
	)

	if loaded:
		_refresh_status()

func _refresh_status() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		level_label.text = "Level --"
		xp_label.text = "XP --"
		hp_label.text = "HP --"
		ki_label.text = "Ki --"
		zeni_label.text = "Zeni --"
		senzu_label.text = "Senzu --"
		return

	var health := player.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	var ki := player.get_node_or_null(
		"Components/KiComponent"
	) as KiComponent
	var experience := player.get_node_or_null(
		"Components/ExperienceComponent"
	) as ExperienceComponent
	var wallet := player.get_node_or_null(
		"Components/WalletComponent"
	) as WalletComponent
	var inventory := player.get_node_or_null(
		"Components/InventoryComponent"
	) as InventoryComponent

	if experience != null:
		level_label.text = "Level  %d" % experience.current_level
		xp_label.text = "XP  %d / %d" % [
			experience.current_experience,
			experience.experience_to_next_level,
		]

	if health != null:
		hp_label.text = "HP  %d / %d" % [
			health.current_health,
			health.max_health,
		]

	if ki != null:
		ki_label.text = "Ki  %.0f / %.0f" % [
			ki.current_ki,
			ki.max_ki,
		]

	if wallet != null:
		zeni_label.text = "Zeni  %d" % wallet.current_amount

	if inventory != null:
		senzu_label.text = "Senzu  x%d" % inventory.get_quantity(
			&"senzu_bean"
		)

	var stats := get_tree().get_first_node_in_group(
		"game_stats"
	) as GameStatsManager
	if stats != null:
		kos_label.text = "KOs  %d" % stats.enemies_defeated
		var total_seconds: int = int(stats.play_time_seconds)
		var minutes: int = total_seconds / 60
		var seconds: int = total_seconds % 60
		time_label.text = "Time  %02d:%02d" % [minutes, seconds]

	_refresh_quest()

func _refresh_quest() -> void:
	var quests := get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if quests == null:
		quest_title_label.text = "Quest"
		quest_objective_label.text = "No quest data"
		return

	var active: Array[Dictionary] = quests.get_active_quests()
	if active.is_empty():
		quest_title_label.text = "Quest"
		quest_objective_label.text = "No active quest"
		return

	var state: Dictionary = active[0]
	quest_title_label.text = str(
		state.get("title", "Quest")
	)

	var objective: String = str(
		state.get("objective_text", "Objective")
	)
	var progress: int = int(state.get("progress", 0))
	var target: int = maxi(
		int(state.get("target_count", 1)),
		1
	)

	quest_objective_label.text = "%s  %d/%d" % [
		objective,
		progress,
		target,
	]
