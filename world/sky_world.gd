class_name SkyWorld
extends Node2D

# The sky above Earth: the 4th layer of the world (Earth's ground, the
# interiors, the regions, and this). Flying high (U while flying) brings the
# player here: the whole planet seen from above, drawn from the same layout
# as the ground, with clouds drifting by and the names of every place.
# Coming down (U or V) lands on exactly the spot below, on Earth.
#
# Scale: one ground tile (32 px) is SKY_TILE px here, so every pixel flown
# in the sky covers GROUND_PER_SKY pixels of ground.

const DATA = preload("res://world/earth_layout_data.gd")
const SCENE_PATH := "res://scenes/world/sky.tscn"
const SKY_TILE: int = DATA.SKY_TILE
const GROUND_PER_SKY := 32.0 / SKY_TILE
const CLOUD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/world/sky_cloud_0.png"),
	preload("res://assets/world/sky_cloud_1.png"),
	preload("res://assets/world/sky_cloud_2.png"),
]
const CLOUD_COUNT := 26

var map_sprite: Sprite2D
var _clouds: Array[Sprite2D] = []
var _cloud_speeds: Array[float] = []
var _labels: Node2D
var _time := 0.0
var _below_label: Label

static func to_sky(ground: Vector2) -> Vector2:
	return ground / GROUND_PER_SKY

static func to_ground(sky: Vector2) -> Vector2:
	return sky * GROUND_PER_SKY

func _ready() -> void:
	add_to_group("sky_world")
	_build_map()
	_build_landmarks()
	_build_clouds()
	_build_hud()

# Nothing to land on up here: coming down is a trip to Earth.
func is_landable_point(_point: Vector2) -> bool:
	return false

func get_map_size() -> Vector2:
	return Vector2(DATA.SIZE * SKY_TILE)

# The landmark or zone below a sky position ("" over the open sea).
func place_below(sky_point: Vector2) -> String:
	var tile := sky_point / SKY_TILE
	var best := ""
	var best_distance := 7.0
	for landmark in DATA.LANDMARKS:
		var distance: float = (landmark[1] as Vector2).distance_to(tile)
		if distance < best_distance:
			best_distance = distance
			best = landmark[0]
	if best.is_empty():
		best = OpenWorld.zone_at_tile(tile).capitalize()
	return best

func _process(delta: float) -> void:
	_time += delta
	var size := get_map_size()
	for index in _clouds.size():
		var cloud := _clouds[index]
		cloud.position.x += _cloud_speeds[index] * delta
		if cloud.position.x > size.x + 80.0:
			cloud.position.x = -80.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and _below_label != null:
		var below := place_below(player.global_position)
		_below_label.text = ("Below: %s" % below if not below.is_empty() else "Over the open sea") + "    U / V  Descend"
	if player != null:
		# Clouds part around the flyer so the ground stays readable.
		for cloud in _clouds:
			var near := cloud.global_position.distance_to(player.global_position)
			cloud.modulate.a = clampf((near - 30.0) / 120.0, 0.25, 1.0) * 0.8

# --- map -----------------------------------------------------------------------

func _build_map() -> void:
	# Rendered offline with the layout (tools/world/build_earth_layout.py).
	map_sprite = Sprite2D.new()
	map_sprite.name = "PlanetMap"
	map_sprite.centered = false
	map_sprite.texture = load(DATA.SKY_PATH) as Texture2D
	map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_sprite.z_as_relative = false
	map_sprite.z_index = -50
	add_child(map_sprite)
	move_child(map_sprite, 0)

# --- landmarks and clouds -----------------------------------------------------

func _build_landmarks() -> void:
	_labels = Node2D.new()
	_labels.name = "Landmarks"
	_labels.z_as_relative = false
	_labels.z_index = 600
	add_child(_labels)
	for landmark in DATA.LANDMARKS:
		var at: Vector2 = (landmark[1] as Vector2) * SKY_TILE
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
		marker.color = _marker_colour(landmark[2])
		marker.position = at
		_labels.add_child(marker)
		var outline := Line2D.new()
		outline.points = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0), Vector2(0, -5)])
		outline.width = 1.0
		outline.default_color = Color(0.08, 0.08, 0.12, 0.9)
		marker.add_child(outline)
		var label := Label.new()
		label.text = landmark[0]
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(1, 1, 0.92))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(100, 10)
		label.position = at + Vector2(-50, 4)
		_labels.add_child(label)

static func _marker_colour(kind: String) -> Color:
	match kind:
		"city", "capsule", "town":
			return Color8(120, 200, 255)
		"kame":
			return Color8(255, 120, 110)
		"arena", "wastes":
			return Color8(255, 190, 90)
		"tower":
			return Color8(250, 240, 140)
	return Color8(170, 240, 150)

func _build_clouds() -> void:
	var size := get_map_size()
	for index in CLOUD_COUNT:
		var cloud := Sprite2D.new()
		var h := EarthTerrain._hash(index * 7 + 3, index * 13 + 5)
		cloud.texture = CLOUD_TEXTURES[h % CLOUD_TEXTURES.size()]
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.position = Vector2(h % int(size.x), (h / 7) % int(size.y))
		var scale_value := 0.9 + float(h % 4) * 0.25
		cloud.scale = Vector2(scale_value, scale_value)
		cloud.z_as_relative = false
		cloud.z_index = 500
		add_child(cloud)
		_clouds.append(cloud)
		_cloud_speeds.append(4.0 + float(h % 7))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SkyHud"
	add_child(layer)
	_below_label = Label.new()
	_below_label.add_theme_font_size_override("font_size", 8)
	_below_label.add_theme_color_override("font_color", Color(1, 1, 0.92))
	_below_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	_below_label.add_theme_constant_override("outline_size", 3)
	_below_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_below_label.anchor_left = 0.0
	_below_label.anchor_right = 1.0
	_below_label.anchor_top = 0.0
	_below_label.anchor_bottom = 0.0
	_below_label.offset_top = 6
	_below_label.offset_bottom = 18
	layer.add_child(_below_label)
