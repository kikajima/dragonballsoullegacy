class_name ComboCounter
extends Control

@onready var count_text: LegacyBitmapText = $Panel/Count
@onready var hits_text: LegacyBitmapText = $Panel/Hits
@onready var damage_text: LegacyBitmapText = $Panel/Damage

var _combo_tracker: ComboTrackerComponent

func _ready() -> void:
	visible = false
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
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
		return

	count_text.set_text(str(hit_count))
	hits_text.set_text("HITS")
	damage_text.set_text("%d DMG" % total_damage)
