class_name KiSenseOverlay
extends Control

# Wisdom lets the player feel the ki of other beings. Every enemy or person
# within the sense radius (CharacterStatsComponent.ki_sense_radius) that is
# off screen shows a pulsing ki marker on the screen edge, pointing at it.
# The marker grows with the being's power and is coloured by how it compares
# with the player. Meditating doubles the radius and also marks beings on
# screen, through walls and scenery.

const EDGE_MARGIN := 16.0
const COLOR_WEAKER := Color(1.0, 0.92, 0.45)
const COLOR_EQUAL := Color(1.0, 0.6, 0.25)
const COLOR_STRONGER := Color(1.0, 0.28, 0.24)
const COLOR_PEACEFUL := Color(0.55, 0.85, 1.0)

var _time: float = 0.0
# [{position: Vector2 (screen), color: Color, size: float, on_screen: bool}]
var _markers: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("ki_sense_overlay")
	# Above the HUD boxes (markers sit on the screen edge), below menus (120).
	z_index = 40
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_markers() -> Array[Dictionary]:
	return _markers

func _process(delta: float) -> void:
	_time += delta
	_markers = compute_markers()
	queue_redraw()

func compute_markers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.is_inside_tree():
		return result
	var meditating := player.is_meditating()
	var radius := player.character_stats.ki_sense_radius(meditating)
	var canvas := get_viewport().get_canvas_transform()
	var screen := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var own := AnalyzePanel.power_of(player)
	for group in [&"enemy", &"npc"]:
		for node in get_tree().get_nodes_in_group(group):
			var being := node as Node2D
			if being == null or not being.is_inside_tree() or being == player:
				continue
			var health := being.get_node_or_null("Components/HealthComponent") as HealthComponent
			if health != null and health.is_dead():
				continue
			var distance := being.global_position.distance_to(player.global_position)
			if distance > radius:
				continue
			var at := canvas * being.global_position
			var on_screen := screen.grow(-4.0).has_point(at)
			if on_screen and not meditating:
				continue
			var power := AnalyzePanel.power_of(being)
			var color := COLOR_PEACEFUL
			if group == &"enemy":
				var ratio := float(power) / float(maxi(own, 1))
				color = COLOR_STRONGER if ratio > 1.2 else (COLOR_EQUAL if ratio >= 0.8 else COLOR_WEAKER)
			if not on_screen:
				at = _edge_point(canvas * player.global_position, at, screen)
			result.append({
				"direction": (being.global_position - player.global_position).normalized(),
				"position": at,
				"color": color,
				"size": clampf(3.0 + log(float(maxi(power, 1))) * 0.7, 3.0, 9.0),
				"on_screen": on_screen,
				"being": being,
			})
	return result

# Where the line from the player to an off-screen point leaves the screen.
func _edge_point(from: Vector2, to: Vector2, screen: Rect2) -> Vector2:
	var inner := screen.grow(-EDGE_MARGIN)
	var direction := to - from
	if direction.is_zero_approx():
		return from
	var t := INF
	if direction.x > 0.0:
		t = minf(t, (inner.end.x - from.x) / direction.x)
	elif direction.x < 0.0:
		t = minf(t, (inner.position.x - from.x) / direction.x)
	if direction.y > 0.0:
		t = minf(t, (inner.end.y - from.y) / direction.y)
	elif direction.y < 0.0:
		t = minf(t, (inner.position.y - from.y) / direction.y)
	return from + direction * clampf(t, 0.0, 1.0)

func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 5.0)
	for marker in _markers:
		var at: Vector2 = marker["position"]
		var color: Color = marker["color"]
		var radius: float = marker["size"] * pulse
		if marker["on_screen"]:
			draw_arc(at, radius + 6.0, 0.0, TAU, 20, Color(color, 0.55), 1.0)
			continue
		# Glow, dark rim, bright core and a chevron pointing at the being.
		var direction: Vector2 = marker["direction"]
		draw_circle(at, radius + 3.0, Color(color, 0.25))
		draw_circle(at, radius * 0.7 + 1.0, Color(0.05, 0.05, 0.1, 0.85))
		draw_circle(at, radius * 0.7, Color(color, 0.95))
		var tip := at + direction * (radius + 6.0)
		var side := direction.orthogonal() * 3.0
		var base := at + direction * (radius + 2.0)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(color, 0.95))
