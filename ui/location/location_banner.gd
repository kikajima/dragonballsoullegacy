class_name LocationBanner
extends Control

@export var display_duration: float = 2.4
@export var fade_duration: float = 0.35

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

var _tween: Tween
var _resting_position: Vector2

func _ready() -> void:
	_style_panel()
	get_viewport().size_changed.connect(_layout_banner)
	_layout_banner()
	visible = false
	modulate.a = 0.0
	call_deferred("_bind_world")

func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a25")
	style.border_color = Color("849aa6")
	style.set_border_width_all(1)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style)

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
	_resting_position = Vector2(
		(viewport_size.x - 200.0) * 0.5,
		viewport_size.y - 112.0
	)
	position = _resting_position
	size = Vector2(200, 25)

func show_location(location_name: String) -> void:
	if location_name.is_empty():
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	label.text = location_name
	visible = true
	modulate.a = 0.0
	position = _resting_position + Vector2(0.0, 4.0)

	_tween = create_tween()
	_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(
		self,
		"position",
		_resting_position,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(display_duration)
	_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide_banner)

func _hide_banner() -> void:
	visible = false
