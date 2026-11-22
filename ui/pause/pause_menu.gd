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

var aura_toggle_button: Button
var aura_color_button: Button
var _aura_swatch: ColorRect

func _ready() -> void:
	visible = false
	# Above world-anchored HUD bits such as the interaction prompt (z 100).
	z_index = 120
	_build_aura_row()
	resume_button.pressed.connect(_resume)
	save_button.pressed.connect(_save)
	load_button.pressed.connect(_load)
	var manager := get_tree().get_first_node_in_group("save_manager") as SaveManager
	if manager != null:
		manager.save_failed.connect(_show_save_error)
		manager.load_failed.connect(_show_save_error)

func _show_save_error(reason: String) -> void:
	status_label.text = reason

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
	_refresh_aura()
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

	status_label.text = "Failed to save."
	if manager.save_game():
		status_label.text = "Game saved."

func _load() -> void:
	var manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if manager == null:
		status_label.text = "SaveManager not found."
		return

	status_label.text = "No valid save found."
	if manager.load_game():
		status_label.text = "Save loaded."
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

# --- Aura options -----------------------------------------------------------

func _build_aura_row() -> void:
	var panel := $Panel as Control
	var line := ColorRect.new()
	line.name = "AuraDivider"
	line.color = Color(0.4, 0.48, 0.62, 0.65)
	line.position = Vector2(10, 172)
	line.size = Vector2(310, 1)
	panel.add_child(line)

	var header := Label.new()
	header.name = "AuraHeader"
	header.text = "AURA"
	header.add_theme_font_size_override("font_size", 7)
	header.position = Vector2(13, 184)
	panel.add_child(header)

	aura_toggle_button = Button.new()
	aura_toggle_button.name = "AuraToggleButton"
	aura_toggle_button.add_theme_font_size_override("font_size", 7)
	aura_toggle_button.position = Vector2(55, 180)
	aura_toggle_button.size = Vector2(70, 21)
	aura_toggle_button.pressed.connect(_toggle_aura)
	panel.add_child(aura_toggle_button)

	aura_color_button = Button.new()
	aura_color_button.name = "AuraColorButton"
	aura_color_button.add_theme_font_size_override("font_size", 7)
	aura_color_button.position = Vector2(135, 180)
	aura_color_button.size = Vector2(110, 21)
	aura_color_button.pressed.connect(cycle_aura_color.bind(1))
	aura_color_button.gui_input.connect(_on_color_button_input)
	panel.add_child(aura_color_button)

	_aura_swatch = ColorRect.new()
	_aura_swatch.name = "AuraSwatch"
	_aura_swatch.position = Vector2(255, 184)
	_aura_swatch.size = Vector2(13, 13)
	panel.add_child(_aura_swatch)

	var hint := Label.new()
	hint.name = "AuraHint"
	hint.text = "< >  color"
	hint.add_theme_font_size_override("font_size", 6)
	hint.modulate = Color(0.7, 0.75, 0.85)
	hint.position = Vector2(275, 186)
	panel.add_child(hint)

func _get_power_aura() -> PowerAuraComponent:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("Visuals/PowerAura") as PowerAuraComponent

func _toggle_aura() -> void:
	var aura := _get_power_aura()
	if aura != null:
		aura.toggle()
	_refresh_aura()

func cycle_aura_color(step: int) -> void:
	var aura := _get_power_aura()
	if aura != null:
		aura.cycle_color(step)
	_refresh_aura()

func _on_color_button_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		cycle_aura_color(-1)
		aura_color_button.accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		cycle_aura_color(1)
		aura_color_button.accept_event()

func _refresh_aura() -> void:
	if aura_toggle_button == null:
		return
	var aura := _get_power_aura()
	if aura == null:
		aura_toggle_button.text = "Aura: --"
		aura_color_button.text = "--"
		return
	aura_toggle_button.text = "Aura: ON" if aura.enabled else "Aura: OFF"
	aura_color_button.text = "<  %s  >" % PowerAuraComponent.get_color_name(aura.color_id)
	_aura_swatch.color = PowerAuraComponent.get_swatch_color(aura.color_id)
