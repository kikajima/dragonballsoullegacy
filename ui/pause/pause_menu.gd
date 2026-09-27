class_name PauseMenu
extends Control

@onready var resume_button: Button = $Panel/ResumeButton
@onready var save_button: Button = $Panel/SaveButton
@onready var load_button: Button = $Panel/LoadButton
@onready var status_label: Label = $Panel/Status

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
		status_label.text = "SaveManager não encontrado."
		return

	status_label.text = (
		"Jogo salvo."
		if manager.save_game()
		else "Falha ao salvar."
	)

func _load() -> void:
	var manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if manager == null:
		status_label.text = "SaveManager não encontrado."
		return

	status_label.text = (
		"Save carregado."
		if manager.load_game()
		else "Nenhum save válido."
	)
