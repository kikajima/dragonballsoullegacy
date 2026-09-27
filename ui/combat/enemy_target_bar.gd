class_name EnemyTargetBar
extends Control

@export var visible_duration: float = 3.0

@onready var name_label: Label = $Panel/Name
@onready var health_bar: ProgressBar = $Panel/HealthBar

var _health: HealthComponent
var _time_left: float = 0.0

func _ready() -> void:
	visible = false
	call_deferred("_bind_feedback")

func _process(delta: float) -> void:
	if not visible:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_hide_target()

func _bind_feedback() -> void:
	var manager := get_tree().get_first_node_in_group(
		"combat_feedback"
	) as CombatFeedbackManager
	if manager == null:
		return

	manager.target_changed.connect(_on_target_changed)

func _on_target_changed(target: Node) -> void:
	if target == null:
		return

	var health := target.get_node_or_null(
		"Components/HealthComponent"
	) as HealthComponent
	if health == null:
		return

	if _health != null and _health.health_changed.is_connected(
		_on_health_changed
	):
		_health.health_changed.disconnect(_on_health_changed)

	_health = health
	_health.health_changed.connect(_on_health_changed)

	var display_name: String = target.name
	if target.has_method("get_display_name"):
		display_name = str(target.call("get_display_name"))

	name_label.text = display_name
	_time_left = visible_duration
	visible = true

	_on_health_changed(
		_health.current_health,
		_health.max_health
	)

func _on_health_changed(
	current_health: int,
	max_health: int
) -> void:
	health_bar.max_value = float(maxi(max_health, 1))
	health_bar.value = float(maxi(current_health, 0))
	_time_left = visible_duration

	if current_health <= 0:
		_time_left = minf(_time_left, 0.8)

func _hide_target() -> void:
	visible = false

	if _health != null and _health.health_changed.is_connected(
		_on_health_changed
	):
		_health.health_changed.disconnect(_on_health_changed)

	_health = null
