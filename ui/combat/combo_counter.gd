class_name ComboCounter
extends Control

@onready var panel: Control = $Panel
@onready var count_text: LegacyBitmapText = $Panel/Count
@onready var hits_text: LegacyBitmapText = $Panel/Hits
@onready var damage_text: LegacyBitmapText = $Panel/Damage

var _combo_tracker: ComboTrackerComponent
var _pulse_tween: Tween
var _previous_hits: int = 0

func _ready() -> void:
	visible = false
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_combo_tracker = player.get_node_or_null(
		"Components/ComboTrackerComponent"
	) as ComboTrackerComponent
	if _combo_tracker == null:
		return

	_combo_tracker.combo_changed.connect(_on_combo_changed)
	_on_combo_changed(
		_combo_tracker.hit_count,
		_combo_tracker.total_damage
	)

func _on_combo_changed(hit_count: int, total_damage: int) -> void:
	if _combo_tracker == null:
		visible = false
		return

	visible = hit_count >= _combo_tracker.minimum_visible_hits
	if not visible:
		_previous_hits = hit_count
		return

	count_text.set_text(str(hit_count))
	hits_text.set_text("HITS")
	damage_text.set_text("%d DMG" % total_damage)

	_apply_combo_color(hit_count)
	_pulse_panel(hit_count)
	_check_milestone(hit_count)
	_previous_hits = hit_count

func _apply_combo_color(hit_count: int) -> void:
	var color: Color = Color.WHITE
	if hit_count >= 20:
		color = Color(1.0, 0.42, 0.25, 1.0)
	elif hit_count >= 10:
		color = Color(1.0, 0.78, 0.24, 1.0)
	elif hit_count >= 5:
		color = Color(0.55, 0.9, 1.0, 1.0)

	count_text.modulate = color
	damage_text.modulate = color

func _pulse_panel(hit_count: int) -> void:
	if panel == null:
		return

	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	var bonus: float = minf(float(hit_count) * 0.008, 0.16)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * (1.08 + bonus)

	_pulse_tween = create_tween()
	_pulse_tween.tween_property(
		panel,
		"scale",
		Vector2.ONE,
		0.10
	)

func _check_milestone(hit_count: int) -> void:
	var milestone: int = 0
	for value in [5, 10, 20, 30, 50]:
		if _previous_hits < value and hit_count >= value:
			milestone = value

	if milestone <= 0:
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not player is Node2D:
		return

	var feedback: CombatFeedbackManager = (
		get_tree().get_first_node_in_group("combat_feedback")
		as CombatFeedbackManager
	)
	if feedback == null:
		return

	feedback.spawn_floating_text(
		"%d HIT COMBO!" % milestone,
		(player as Node2D).global_position + Vector2(0, -34),
		Color(1.0, 0.82, 0.26, 1.0)
	)
	feedback.request_camera_shake(
		1.0 + minf(float(milestone) * 0.03, 1.5),
		0.08
	)
