class_name ScreenTransition
extends Control

signal fade_out_finished
signal fade_in_finished

@export var default_duration: float = 0.22

@onready var shade: ColorRect = $Shade

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.modulate.a = 0.0
	visible = true

func fade_out(duration: float = -1.0) -> void:
	var time: float = (
		default_duration
		if duration < 0.0
		else duration
	)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(
		shade,
		"modulate:a",
		1.0,
		maxf(time, 0.0)
	)
	await _tween.finished
	fade_out_finished.emit()

func fade_in(duration: float = -1.0) -> void:
	var time: float = (
		default_duration
		if duration < 0.0
		else duration
	)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(
		shade,
		"modulate:a",
		0.0,
		maxf(time, 0.0)
	)
	await _tween.finished
	fade_in_finished.emit()

func snap_to_black() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	shade.modulate.a = 1.0

func snap_to_clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	shade.modulate.a = 0.0
