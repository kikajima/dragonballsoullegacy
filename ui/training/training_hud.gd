class_name TrainingHUD
extends Control

@onready var title_label: Label = $Panel/Title
@onready var info_label: Label = $Panel/Info
@onready var prompt_label: Label = $Panel/Prompt

var _training: TrainingManager
var _prompt: String = ""

func _ready() -> void:
	position = Vector2(286.0, 60.0)
	size = Vector2(184.0, 40.0)
	visible = false
	call_deferred("_bind_training")

func _bind_training() -> void:
	_training = get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
	if _training == null:
		return

	_training.session_changed.connect(_on_session_changed)
	_training.progress_changed.connect(_on_progress_changed)
	_training.gravity_changed.connect(_on_gravity_changed)
	_training.prompt_changed.connect(_on_prompt_changed)
	_refresh()

func _on_session_changed(
	_mode: StringName,
	_active: bool
) -> void:
	_refresh()

func _on_progress_changed(
	_mode: StringName,
	_session_xp: int,
	_combo: int,
	_best_combo: int
) -> void:
	_refresh()

func _on_gravity_changed(_multiplier: float) -> void:
	_refresh()

func _on_prompt_changed(text_value: String) -> void:
	_prompt = text_value
	_refresh()

func _refresh() -> void:
	if _training == null:
		visible = false
		return

	visible = (
		_training.active_mode != TrainingManager.MODE_NONE
		or _training.gravity_multiplier > 1.0
	)
	if not visible:
		return

	var mode_text: String = (
		String(_training.active_mode)
		.replace("_", " ")
		.capitalize()
	)
	if _training.active_mode == TrainingManager.MODE_NONE:
		mode_text = "Training Chamber"

	var training_rank: int = 1 + int(
		floor(float(_training.total_training_xp) / 100.0)
	)

	title_label.text = "%s  |  %.0fx GRAVITY" % [
		mode_text,
		_training.gravity_multiplier,
	]
	info_label.text = "RANK %d  +%d XP  COMBO %d  BEST %d" % [
		training_rank,
		_training.session_xp,
		_training.combo,
		_training.best_combo,
	]
	prompt_label.text = _prompt
