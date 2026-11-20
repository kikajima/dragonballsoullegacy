class_name LocationBanner
extends Control

@export var display_duration: float = 2.4
@export var fade_duration: float = 0.35

@onready var label: Label = $Panel/Label

var _tween: Tween

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_banner)
	_layout_banner()
	visible = false
	modulate.a = 0.0
	call_deferred("_bind_world")

func _bind_world() -> void:
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null:
		world.world_change_started.connect(_on_world_change)

func _on_world_change(_path: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false

func _layout_banner() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2((viewport_size.x - 200.0) * 0.5, viewport_size.y - 112.0)
	size = Vector2(200, 25)

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
