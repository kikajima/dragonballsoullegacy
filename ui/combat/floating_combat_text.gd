class_name FloatingCombatText
extends Node2D

@export var lifetime: float = 0.65
@export var rise_distance: float = 18.0

@onready var label: Label = $Label

var _elapsed: float = 0.0
var _start_position: Vector2

func _ready() -> void:
	_start_position = position

func setup(text_value: String, text_color: Color) -> void:
	label.text = text_value
	label.modulate = text_color

func _process(delta: float) -> void:
	_elapsed += delta

	var ratio: float = clampf(
		_elapsed / maxf(lifetime, 0.001),
		0.0,
		1.0
	)

	position = _start_position + Vector2(
		0.0,
		-rise_distance * ratio
	)
	label.modulate.a = 1.0 - ratio

	if ratio >= 1.0:
		queue_free()
