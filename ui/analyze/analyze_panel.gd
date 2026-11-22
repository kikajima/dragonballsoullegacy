class_name AnalyzePanel
extends Control

# Result of Analyze (T). What is revealed depends on the player's
# Intelligence tier (CharacterStatsComponent.analyze_tier):
#   0  condition in words, power unknown
#   1  HP to the nearest 10%, power compared to the player
#   2  exact HP and power level
#   3  also how hard its hits and ki shots land

const PANEL_SIZE := Vector2(156, 64)
const SHOW_SECONDS := 6.0
const FONT_SIZE := 8
const COLOR_PANEL := Color(0.025, 0.035, 0.06, 0.92)
const COLOR_EDGE := Color(0.3, 0.42, 0.62)
const COLOR_TEXT := Color(0.92, 0.94, 1.0)
const COLOR_DIM := Color(0.6, 0.66, 0.78)
const COLOR_GOLD := Color(1.0, 0.85, 0.35)

var _target: Node2D
var _tier: int = 0
var _time_left: float = 0.0
var _lines: Array[Label] = []
var _title: Label
var _panel: Panel

func _ready() -> void:
	add_to_group("analyze_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	position = Vector2(480 - PANEL_SIZE.x - 6, 40)
	_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_EDGE
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_title = _make_label(COLOR_GOLD)
	_title.position = Vector2(6, 3)
	_panel.add_child(_title)
	for i in 4:
		var line := _make_label(COLOR_TEXT)
		line.position = Vector2(6, 16 + i * 11)
		_panel.add_child(line)
		_lines.append(line)
	visible = false

func is_showing() -> bool:
	return visible

func get_lines() -> PackedStringArray:
	var result := PackedStringArray([_title.text])
	for line in _lines:
		if not line.text.is_empty():
			result.append(line.text)
	return result

func show_analysis(target: Node2D, tier: int) -> void:
	_target = target
	_tier = tier
	_time_left = SHOW_SECONDS
	visible = true
	modulate.a = 1.0
	_refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	if get_tree().paused:
		return
	_time_left -= delta
	if _time_left <= 0.0 or not is_instance_valid(_target):
		visible = false
		return
	modulate.a = clampf(_time_left / 0.4, 0.0, 1.0)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_target):
		return
	var name_text := String(_target.name)
	if _target.has_method("get_display_name"):
		name_text = str(_target.call("get_display_name"))
	var rank := ""
	if _target.has_method("get_intelligence_tier_name"):
		rank = "  [%s]" % str(_target.call("get_intelligence_tier_name"))
	_title.text = "ANALYZE: %s%s" % [name_text, rank]
	var texts := describe(_target, _tier)
	for i in _lines.size():
		_lines[i].text = texts[i] if i < texts.size() else ""
		_lines[i].add_theme_color_override("font_color", COLOR_DIM if i == texts.size() - 1 and _tier < 3 else COLOR_TEXT)

# The readable lines for a target at an Intelligence tier.
static func describe(target: Node, tier: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var health := target.get_node_or_null("Components/HealthComponent") as HealthComponent
	if health == null:
		lines.append("A peaceful person. No fighting ki.")
		return lines
	lines.append("HP: " + health_reading(health, tier))
	var power := power_of(target)
	var player := target.get_tree().get_first_node_in_group("player")
	var own := power_of(player) if player != null else power
	match tier:
		0:
			lines.append("Power: ???")
		1:
			lines.append("Power: " + compare_power(power, own))
		_:
			lines.append("Power level: %d  (%s)" % [power, compare_power(power, own)])
	if tier >= 3:
		var melee := target.get_node_or_null("Components/MeleeCombatComponent") as MeleeCombatComponent
		if melee != null:
			lines.append("Hits ~%d  Kicks ~%d" % [
				roundi(float(melee.damage) * melee._damage_multiplier),
				roundi(float(melee.kick_damage) * melee._damage_multiplier),
			])
	else:
		lines.append("Study to read more (Intelligence)")
	return lines

static func health_reading(health: HealthComponent, tier: int) -> String:
	var ratio := health.get_health_ratio()
	match tier:
		0:
			if ratio > 0.75:
				return "Healthy"
			if ratio > 0.4:
				return "Hurt"
			if ratio > 0.15:
				return "Badly hurt"
			return "Near defeat"
		1:
			return "~%d%%" % (roundi(ratio * 10.0) * 10)
	return "%d / %d" % [health.current_health, health.max_health]

static func power_of(being: Node) -> int:
	if being == null:
		return 1
	if being.has_method("get_power_level"):
		return int(being.call("get_power_level"))
	var health := being.get_node_or_null("Components/HealthComponent") as HealthComponent
	var melee := being.get_node_or_null("Components/MeleeCombatComponent") as MeleeCombatComponent
	var value := 0.0
	if health != null:
		value += float(health.max_health) * 0.6
	if melee != null:
		value += float(melee.damage) * 8.0 * melee._damage_multiplier
	return maxi(roundi(value), 1)

static func compare_power(power: int, own: int) -> String:
	var ratio := float(power) / float(maxi(own, 1))
	if ratio > 2.0:
		return "far stronger"
	if ratio > 1.2:
		return "stronger"
	if ratio >= 0.8:
		return "about equal"
	if ratio >= 0.4:
		return "weaker"
	return "far weaker"

func _make_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
