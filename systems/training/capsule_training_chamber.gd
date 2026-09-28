class_name CapsuleTrainingChamber
extends Node2D

@onready var training_floor: Polygon2D = $TrainingFloor

var _training: TrainingManager
var _pulse_time: float = 0.0

func _ready() -> void:
	call_deferred("_bind_training")

func _process(delta: float) -> void:
	if _training == null or _training.gravity_multiplier <= 1.0:
		training_floor.modulate = Color.WHITE
		return

	_pulse_time += delta * _training.gravity_multiplier * 0.35
	var pulse: float = 0.88 + sin(_pulse_time) * 0.08
	var gravity_tint: float = clampf(
		(_training.gravity_multiplier - 1.0) / 9.0,
		0.0,
		1.0
	)
	training_floor.modulate = Color(
		1.0,
		lerpf(1.0, 0.58, gravity_tint) * pulse,
		lerpf(1.0, 0.62, gravity_tint) * pulse,
		1.0
	)

func _bind_training() -> void:
	_training = get_tree().get_first_node_in_group(
		"training_manager"
	) as TrainingManager
