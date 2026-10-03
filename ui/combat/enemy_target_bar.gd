class_name EnemyTargetBar
extends Control

@export var visible_duration: float = 3.0

@onready var name_label: Label = $Panel/Name
@onready var tier_label: Label = $Panel/Tier
@onready var health_bar: ProgressBar = $Panel/HealthBar
@onready var health_text: Label = $Panel/HealthBar/HealthText

var _health: HealthComponent
var _time_left: float = 0.0

func _ready() -> void:
	position = Vector2(180.0, 5.0)
	size = Vector2(120.0, 20.0)
	visible = false
	call_deferred("_bind_feedback")

func _process(delta: float) -> void:
	if not visible:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_hide_target()

func _bind_feedback() -> void:
	var manager: CombatFeedbackManager = (
		get_tree().get_first_node_in_group("combat_feedback")
		as CombatFeedbackManager
	)
	if manager == null:
		return

	manager.target_changed.connect(_on_target_changed)

func _on_target_changed(target: Node) -> void:
	if target == null:
		return

	var health: HealthComponent = target.get_node_or_null(
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

	var display_name: String = String(target.name)
	if target.has_method("get_display_name"):
		display_name = str(target.call("get_display_name"))

	name_label.text = display_name

	var tier_name: String = "Common"
	if target.has_method("get_intelligence_tier_name"):
		tier_name = str(
			target.call("get_intelligence_tier_name")
		)

	tier_label.text = tier_name
	tier_label.modulate = _tier_color(tier_name)
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
	var safe_max: int = maxi(max_health, 1)
	var safe_current: int = clampi(
		current_health,
		0,
		safe_max
	)

	health_bar.max_value = float(safe_max)
	health_bar.value = float(safe_current)
	health_text.text = "%d / %d" % [
		safe_current,
		safe_max,
	]
	_time_left = visible_duration

	if current_health <= 0:
		_time_left = minf(_time_left, 0.8)

func _tier_color(tier_name: String) -> Color:
	var normalized: String = tier_name.to_lower()
	if normalized.contains("elite") or normalized.contains("boss"):
		return Color(1.0, 0.54, 0.28, 1.0)
	if normalized.contains("uncommon") or normalized.contains("veteran"):
		return Color(0.45, 0.9, 1.0, 1.0)
	if normalized.contains("training") or normalized.contains("spar"):
		return Color(0.72, 0.78, 0.88, 1.0)
	return Color.WHITE

func _hide_target() -> void:
	visible = false

	if _health != null and _health.health_changed.is_connected(
		_on_health_changed
	):
		_health.health_changed.disconnect(_on_health_changed)

	_health = null
