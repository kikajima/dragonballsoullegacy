class_name QuestTracker
extends Control

# HUD box with the tracked quest (QuestManager.get_tracked_quest): its title,
# up to three objectives with their progress, and an arrow pointing to where
# the current objective takes place, when it has a place on the map.

const NPC_NAMES := {
	"roshi": "Master Roshi", "bulma": "Bulma", "piccolo": "Piccolo",
	"turtle": "Turtle", "krillin": "Krillin",
}
const MAX_LINES := 3

@onready var title_label: Label = $Panel/Title
@onready var objective_label: Label = $Panel/Objective

var _quest_manager: QuestManager
var _arrow: Control
var _target_point: Variant = null
var _arrow_check_left := 0.0

func _ready() -> void:
	_layout_tracker()
	get_viewport().size_changed.connect(_layout_tracker)
	objective_label.position = Vector2(6, 15)
	objective_label.size = Vector2(166, 29)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	objective_label.clip_text = true
	objective_label.add_theme_constant_override("line_spacing", -2)
	title_label.clip_text = true
	title_label.size.x = 150
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.position = Vector2(162, 3)
	_arrow.size = Vector2(12, 12)
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)
	visible = false
	call_deferred("_bind_manager")

func _layout_tracker() -> void:
	position = Vector2(get_viewport_rect().size.x - 186, 50)
	size = Vector2(178, 46)

func _bind_manager() -> void:
	_quest_manager = get_tree().get_first_node_in_group(
		"quest_manager"
	) as QuestManager
	if _quest_manager == null:
		return

	_quest_manager.quest_started.connect(_on_quest_changed)
	_quest_manager.quest_updated.connect(_on_quest_progress)
	_quest_manager.quest_completed.connect(_on_quest_changed)
	_quest_manager.quest_ready.connect(_on_quest_changed)
	_quest_manager.tracked_changed.connect(_on_quest_changed)
	_quest_manager.quests_restored.connect(_refresh)
	_refresh()

func _on_quest_changed(_quest_id: StringName) -> void:
	_refresh()

func _on_quest_progress(
	_quest_id: StringName,
	_progress: int,
	_target_count: int
) -> void:
	_refresh()

func _process(delta: float) -> void:
	if not visible or _target_point == null:
		return
	_arrow_check_left -= delta
	if _arrow_check_left <= 0.0:
		_arrow_check_left = 0.1
		_arrow.queue_redraw()

func _refresh() -> void:
	if _quest_manager == null:
		visible = false
		return

	var state := _quest_manager.get_tracked_quest()
	if state.is_empty():
		visible = false
		return

	title_label.text = str(state.get("title", "Quest"))
	var lines: Array[String] = []
	var objectives: Array = state.get("objectives", [])
	var current := QuestManager.current_objective(state)
	if str(state.get("status", "")) == QuestManager.STATUS_READY:
		var npc := str(state.get("turn_in", ""))
		lines.append("Report to %s" % NPC_NAMES.get(npc, npc.capitalize()))
	else:
		for objective: Dictionary in objectives:
			if lines.size() >= MAX_LINES:
				break
			var progress := int(objective.get("progress", 0))
			var target := maxi(int(objective.get("target", 1)), 1)
			var text := str(objective.get("text", "Objective"))
			if progress >= target and objectives.size() > MAX_LINES:
				continue
			if target > 1 or progress >= target:
				text += "  %d/%d" % [progress, target]
			lines.append(("+ " if progress >= target else "- ") + text)
	objective_label.text = "\n".join(lines)
	_target_point = QuestManager.objective_point(current) if str(state.get("status", "")) != QuestManager.STATUS_READY else null
	_arrow.visible = _target_point != null
	_arrow.queue_redraw()
	visible = true

func _draw_arrow() -> void:
	if _target_point == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or get_tree().get_first_node_in_group("open_world") == null:
		return
	var offset: Vector2 = (_target_point as Vector2) * 32.0 - player.global_position
	var center := _arrow.size / 2.0
	if offset.length() < 96.0:
		_arrow.draw_circle(center, 3.0, Color(0.5, 1.0, 0.6))
		return
	var direction := offset.normalized()
	var side := direction.orthogonal()
	var tip := center + direction * 5.5
	var back := center - direction * 4.0
	_arrow.draw_colored_polygon(PackedVector2Array([
		tip, back + side * 4.0, center - direction * 1.5, back - side * 4.0,
	]), Color(1.0, 0.85, 0.35))
