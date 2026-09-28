class_name TrainingPunchingBag
extends Area2D

@export var prompt_window: float = 0.55
@export var min_prompt_delay: float = 0.75
@export var max_prompt_delay: float = 1.55

@onready var visual: Polygon2D = $Visual

var _prompt_open: bool = false
var _prompt_left: float = 0.0
var _next_prompt_left: float = 0.6
var _flash_tween: Tween

func _process(delta: float) -> void:
	var training := _get_training()
	if (
		training == null
		or training.active_mode
			!= TrainingManager.MODE_PUNCHING_BAG
	):
		_prompt_open = false
		return

	if _prompt_open:
		_prompt_left -= delta
		if _prompt_left <= 0.0:
			_prompt_open = false
			training.set_prompt("WAIT...")
			training.register_miss()
			_schedule_next_prompt()
		return

	_next_prompt_left -= delta
	if _next_prompt_left <= 0.0:
		_prompt_open = true
		_prompt_left = prompt_window
		training.set_prompt("STRIKE!")

func get_interaction_label() -> String:
	var training := _get_training()
	if (
		training != null
		and training.active_mode
			== TrainingManager.MODE_PUNCHING_BAG
	):
		return "Stop Punching Bag"

	return "Start Punching Bag"

func interact(_actor: Node) -> void:
	var training := _get_training()
	if training == null:
		return

	if training.active_mode == TrainingManager.MODE_PUNCHING_BAG:
		training.stop_training()
		_prompt_open = false
		return

	training.start_training(TrainingManager.MODE_PUNCHING_BAG)
	training.set_prompt("WAIT...")
	_schedule_next_prompt()

func receive_hit(
	_damage: int,
	_source_position: Vector2 = Vector2.ZERO
) -> int:
	var training := _get_training()
	if training == null:
		return 0

	if training.active_mode != TrainingManager.MODE_PUNCHING_BAG:
		training.start_training(TrainingManager.MODE_PUNCHING_BAG)
		training.set_prompt("WAIT...")
		_schedule_next_prompt()
		_flash()
		return 1

	if _prompt_open:
		_prompt_open = false
		training.register_success(3)
		training.set_prompt("GOOD!")
		_schedule_next_prompt()
	else:
		training.register_miss()
		training.set_prompt("TOO EARLY")

	_flash()
	return 1

func can_receive_hit() -> bool:
	return true

func _schedule_next_prompt() -> void:
	_next_prompt_left = randf_range(
		min_prompt_delay,
		max_prompt_delay
	)

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	visual.modulate = Color(1.0, 0.75, 0.45, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		visual,
		"modulate",
		Color.WHITE,
		0.12
	)

func _get_training() -> TrainingManager:
	return get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
