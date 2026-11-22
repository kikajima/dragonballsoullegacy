class_name DragonRadarHUD
extends Control

# Small radar in the bottom-left corner, shown while the Dragon Radar is in
# the bag and the player is on Earth: a green screen with the nearest ball's
# direction and distance (10 m per tile).

const RADIUS := 26.0
const RANGE := 2400.0 # px shown on the screen edge

var _player: Node2D
var _inventory: InventoryComponent
var _manager: DragonBallManager
var _time := 0.0
var _target: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("dragon_radar_hud")
	_layout()
	get_viewport().size_changed.connect(_layout)
	visible = false

func _layout() -> void:
	size = Vector2(RADIUS * 2 + 4, RADIUS * 2 + 16)
	position = Vector2(8, get_viewport_rect().size.y - size.y - 8)

func _process(delta: float) -> void:
	_time += delta
	visible = _should_show()
	if visible:
		_target = _manager.nearest_ball(_player.global_position)
		queue_redraw()

func _should_show() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		_inventory = null
	if _player == null:
		return false
	if _inventory == null:
		_inventory = _player.get_node_or_null("Components/InventoryComponent") as InventoryComponent
	if _manager == null:
		_manager = get_tree().get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	if _inventory == null or _manager == null:
		return false
	if _inventory.get_bag_quantity(&"dragon_radar") <= 0:
		return false
	return get_tree().get_first_node_in_group("open_world") != null

func _draw() -> void:
	var center := Vector2(RADIUS + 2, RADIUS + 2)
	draw_circle(center, RADIUS + 2, Color(0.75, 0.78, 0.8))
	draw_circle(center, RADIUS, Color(0.08, 0.35, 0.12))
	for ring in [RADIUS * 0.33, RADIUS * 0.66]:
		draw_arc(center, ring, 0, TAU, 24, Color(0.3, 0.75, 0.35, 0.6), 1.0)
	draw_line(center - Vector2(RADIUS, 0), center + Vector2(RADIUS, 0), Color(0.3, 0.75, 0.35, 0.5), 1.0)
	draw_line(center - Vector2(0, RADIUS), center + Vector2(0, RADIUS), Color(0.3, 0.75, 0.35, 0.5), 1.0)
	draw_circle(center, 1.5, Color(1, 1, 1))
	var font := get_theme_default_font()
	var text := ""
	if _manager.is_stone():
		text = "STONE"
	elif _target.is_empty():
		text = "-"
	else:
		var offset: Vector2 = _target["point"] - _player.global_position
		var on_screen := offset.limit_length(RANGE) / RANGE * (RADIUS - 3)
		var blink := 0.6 + 0.4 * sin(_time * 8.0)
		draw_circle(center + on_screen, 2.5, Color(1.0, 0.75, 0.15, blink))
		text = "%s %dm" % [compass(offset), roundi(offset.length() / 32.0 * 10.0)]
	draw_string(font, Vector2(0, size.y - 2), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, Color(0.85, 1.0, 0.85))

static func compass(offset: Vector2) -> String:
	if offset.length() < 16.0:
		return "HERE"
	var names := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	var index := wrapi(roundi(offset.angle() / (TAU / 8.0)), 0, 8)
	return names[index]
