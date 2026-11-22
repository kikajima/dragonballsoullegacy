class_name StatusMenu
extends Control

# Status screen (C): the five trained attributes with their level, training
# progress, current effects and how to train them. Pauses the game.

const PANEL_RECT := Rect2(24, 12, 432, 246)
const ROW_TOP := 24.0
const ROW_HEIGHT := 42.0
const BAR_SIZE := Vector2(120, 4)
const FONT_SIZE := 8
const COLOR_PANEL := Color(0.025, 0.035, 0.06, 0.97)
const COLOR_EDGE := Color(0.24, 0.32, 0.48)
const COLOR_TEXT := Color(0.92, 0.94, 1.0)
const COLOR_DIM := Color(0.55, 0.6, 0.7)
const COLOR_GOLD := Color(1.0, 0.85, 0.35)
const COLOR_BAR := Color(0.4, 0.75, 1.0)
const COLOR_BAR_BACK := Color(0.1, 0.14, 0.22)

const TRAINING := {
	&"strength": "Train: land punches, kicks and sword cuts",
	&"agility": "Train: run, dash, fly fast, dash through enemy shots",
	&"vigor": "Train: stay under gravity (Capsule Corp chamber)",
	&"wisdom": "Train: use ki techniques and meditate (M)",
	&"intelligence": "Train: study at the library, university or lab",
}

var _stats: CharacterStatsComponent
var _panel: ColorRect
var _rows: Control
var _header: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 120
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("status_menu")
	_build()
	visible = false

func is_open() -> bool:
	return visible

func open() -> void:
	if not _bind():
		return
	visible = true
	get_tree().paused = true
	refresh()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("status_menu") and _can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("status_menu") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _can_open() -> bool:
	if get_tree().paused:
		return false
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as Control
	return dialogue == null or not dialogue.visible

func _bind() -> bool:
	if _stats != null and is_instance_valid(_stats):
		return true
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	_stats = player.get_node_or_null("Components/CharacterStats") as CharacterStatsComponent
	return _stats != null

# Effect lines shown for each stat.
static func effects_text(stats: CharacterStatsComponent, stat: StringName) -> String:
	match stat:
		CharacterStatsComponent.STRENGTH:
			return "Melee damage x%.2f   Bag +%d spaces" % [
				stats.melee_damage_multiplier(), stats.carry_bonus_slots()]
		CharacterStatsComponent.AGILITY:
			return "Speed x%.2f   Dodge %d%%" % [
				stats.move_speed_multiplier(), roundi(stats.dodge_chance() * 100.0)]
		CharacterStatsComponent.VIGOR:
			return "Max HP +%d   Gravity limit %s" % [
				stats.max_health_bonus(), TrainingManager.format_gravity(stats.gravity_tolerance())]
		CharacterStatsComponent.WISDOM:
			return "Ki damage x%.2f   Cooldowns x%.2f   Ki sense %dm" % [
				stats.magic_damage_multiplier(), stats.special_cooldown_multiplier(),
				roundi(stats.ki_sense_radius() / 16.0)]
		CharacterStatsComponent.INTELLIGENCE:
			var reads := ["condition", "HP %", "exact HP + power", "HP, power + damage"]
			return "Analyze (T): %s   Read attacks %d%%" % [
				reads[stats.analyze_tier()], roundi(stats.attack_read_chance() * 100.0)]
	return ""

func refresh() -> void:
	if not _bind():
		return
	for child in _rows.get_children():
		child.queue_free()
	var total := 0
	for index in CharacterStatsComponent.STATS.size():
		var stat: StringName = CharacterStatsComponent.STATS[index]
		total += _stats.get_level(stat)
		_rows.add_child(_make_row(stat, ROW_TOP + index * ROW_HEIGHT))
	_header.text = "STATUS          C / Esc: close          Total %d" % total

func _make_row(stat: StringName, y: float) -> Control:
	var row := Control.new()
	row.position = Vector2(10, y)
	var level := _stats.get_level(stat)
	var title := _make_label(CharacterStatsComponent.stat_name(stat).to_upper(), COLOR_GOLD)
	row.add_child(title)
	var level_label := _make_label("Lv %d" % level, COLOR_TEXT)
	level_label.position = Vector2(86, 0)
	row.add_child(level_label)
	var back := ColorRect.new()
	back.color = COLOR_BAR_BACK
	back.position = Vector2(130, 5)
	back.size = BAR_SIZE
	row.add_child(back)
	var fill := ColorRect.new()
	fill.color = COLOR_BAR
	fill.position = back.position
	fill.size = Vector2(BAR_SIZE.x * _stats.get_progress(stat), BAR_SIZE.y)
	row.add_child(fill)
	var xp_text := "MAX" if level >= CharacterStatsComponent.MAX_LEVEL else "%d / %d XP" % [
		floori(_stats.get_xp(stat)), roundi(_stats.xp_to_next(level))]
	var xp_label := _make_label(xp_text, COLOR_DIM)
	xp_label.position = Vector2(258, 0)
	row.add_child(xp_label)
	var effects := _make_label(effects_text(_stats, stat), COLOR_TEXT)
	effects.position = Vector2(0, 12)
	row.add_child(effects)
	var hint := _make_label(TRAINING.get(stat, ""), COLOR_DIM)
	hint.position = Vector2(0, 23)
	row.add_child(hint)
	return row

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = ColorRect.new()
	_panel.color = COLOR_PANEL
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	add_child(_panel)
	_header = _make_label("STATUS", COLOR_TEXT)
	_header.position = Vector2(10, 6)
	_panel.add_child(_header)
	var divider := ColorRect.new()
	divider.color = COLOR_EDGE
	divider.position = Vector2(8, 20)
	divider.size = Vector2(PANEL_RECT.size.x - 16, 1)
	_panel.add_child(divider)
	_rows = Control.new()
	_panel.add_child(_rows)

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
