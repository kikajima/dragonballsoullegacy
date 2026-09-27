class_name LocationBanner
extends Control

@export var display_duration: float = 2.4
@export var fade_duration: float = 0.35

@onready var label: Label = $Panel/Label

var _tween: Tween

func _ready() -> void:
	visible = false
	modulate.a = 0.0

func show_location(location_name: String) -> void:
	if location_name.is_empty():
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	label.text = location_name
	visible = true
	modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		fade_duration
	)
	_tween.tween_interval(display_duration)
	_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	)
	_tween.tween_callback(_hide_banner)

func _hide_banner() -> void:
	visible = false
