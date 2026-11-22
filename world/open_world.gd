class_name OpenWorld
extends Node2D

# Earth, the open world: one continuous ground map.
# - EarthTerrain paints every tile from the layout (sea, beaches, plains,
#   forests, wastes, mountains, snow, rivers and paths).
# - Region scenes (West City, Rocky Wastes, Kame Island) sit on top at
#   their place in the layout and keep their own art, NPCs and scripts.
#   Their old closing walls and camera limits are removed.
# - Zones (Northern Mountains, Holy Land Forest...) announce themselves with
#   the location banner as you walk or fly in.
# - Flyers only land on walkable ground. Going up to the sky (SkyWorld)
#   shows the whole planet; coming down lands on the same spot here.

const DATA = preload("res://world/earth_layout_data.gd")
const SCENE_PATH := "res://scenes/world/earth.tscn"
const TILE := 32

# Where the old separate maps sit in this world: their top-left corner.
# Used to upgrade old saves and by tools that think in region coordinates.
const LEGACY_OFFSETS := {
	"res://scenes/world/kame_island.tscn": Vector2(5504, 2752),
	"res://scenes/world/west_city_outskirts.tscn": Vector2(1664, 2112),
	"res://scenes/world/rocky_wastes.tscn": Vector2(2944, 2112),
}
# Region areas of the first open world (save version 6).
const V6_OFFSETS := {
	"res://scenes/world/kame_island.tscn": Rect2(240, 760, 960, 544),
	"res://scenes/world/west_city_outskirts.tscn": Rect2(1760, 300, 1280, 720),
	"res://scenes/world/rocky_wastes.tscn": Rect2(3040, 300, 1280, 720),
}

# Nodes inside the regions that only made sense while each region was its
# own closed map (walls, region-to-region portals).
@export var removed_nodes: Array[NodePath] = []

var terrain: EarthTerrain
var _regions: Array[Node2D] = []
var _region_rects: Dictionary = {}
var _zone_check_left: float = 0.0
var _current_zone: String = ""

static func regions_of(world: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if world is OpenWorld:
		result.assign((world as OpenWorld).get_regions())
	elif world is Node2D:
		result.append(world as Node2D)
	return result

# Earth position of a point given in an old map's coordinates.
static func from_legacy(scene_path: String, local: Vector2) -> Vector2:
	return local + LEGACY_OFFSETS.get(scene_path, Vector2.ZERO)

# Earth position of a point saved by the first open world (version 6).
static func from_v6(point: Vector2) -> Vector2:
	for path in V6_OFFSETS:
		var rect: Rect2 = V6_OFFSETS[path]
		if rect.has_point(point):
			return from_legacy(path, point - rect.position)
	# Open sea of the old layout: start over on Kame Island.
	return from_legacy("res://scenes/world/kame_island.tscn", Vector2(480, 405))

static func world_size() -> Vector2:
	return Vector2(DATA.SIZE) * TILE

static func zone_at_tile(tile: Vector2) -> String:
	for zone in DATA.ZONES:
		if Geometry2D.is_point_in_polygon(tile, PackedVector2Array(zone[1])):
			return zone[0]
	return ""

func _ready() -> void:
	add_to_group("open_world")
	_collect_regions()
	for path in removed_nodes:
		var node := get_node_or_null(path)
		if node != null:
			node.get_parent().remove_child(node)
			node.queue_free()
	_build_terrain()
	var wild := WildEncounterDirector.new()
	wild.name = "WildEncounters"
	add_child(wild)
	var balls := DragonBallField.new()
	balls.name = "DragonBalls"
	add_child(balls)
	_place_town_stalls()

# Landmarks without a region of their own get a market stall.
const TOWN_STALLS := [[&"ginger_town", Vector2(71, 51)]]

func _place_town_stalls() -> void:
	for entry in TOWN_STALLS:
		var point: Vector2 = (entry[1] + Vector2(0.5, 0.5)) * TILE
		if not is_landable_point(point):
			point = nearest_land_point(point)
		var stall := ServicePoint.new()
		stall.name = "Stall_%s" % entry[0]
		stall.kind = "shop"
		stall.shop_id = entry[0]
		stall.position = to_local(point)
		add_child(stall)

func get_regions() -> Array[Node2D]:
	return _regions

func get_bounds() -> Rect2:
	var camera_bounds := get_node_or_null("CameraBounds") as WorldCameraBounds
	return camera_bounds.bounds if camera_bounds != null else Rect2()

func get_region_rect(region: Node2D) -> Rect2:
	return _region_rects.get(region, Rect2())

func region_at(point: Vector2) -> Node2D:
	for region in _regions:
		if (_region_rects[region] as Rect2).has_point(point):
			return region
	return null

func zone_at(point: Vector2) -> String:
	return zone_at_tile(point / TILE)

# Flight: only land on ground, never on water or a mountain.
func is_landable_point(point: Vector2) -> bool:
	var region := region_at(point)
	if region != null:
		if region.has_method("is_landable_point"):
			return region.is_landable_point(point)
		return true
	return terrain != null and terrain.is_walkable(point)

# The closest walkable spot, searching outwards tile by tile. Used when a
# flyer is forced down far out at sea.
func nearest_land_point(point: Vector2) -> Vector2:
	var center := Vector2i(floori(point.x / TILE), floori(point.y / TILE))
	for radius in range(1, 80):
		var best := Vector2.INF
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := (Vector2(center + Vector2i(dx, dy)) + Vector2(0.5, 0.5)) * TILE
				if is_landable_point(candidate) and candidate.distance_to(point) < best.distance_to(point):
					best = candidate
		if best != Vector2.INF:
			return best
	return point

func _collect_regions() -> void:
	for child in get_children():
		var region := child as Node2D
		if region == null:
			continue
		var limits := region.get_node_or_null("CameraBounds") as WorldCameraBounds
		if limits == null:
			continue
		var rect := Rect2(region.position + limits.bounds.position, limits.bounds.size)
		_regions.append(region)
		_region_rects[region] = rect
		region.add_to_group("world_region")
		# Only the world's own bounds may drive the camera and flight.
		limits.remove_from_group("world_bounds")
		region.remove_child(limits)
		limits.queue_free()

func _build_terrain() -> void:
	terrain = EarthTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	move_child(terrain, 0)
	var land: Array[Rect2] = []
	var islands: Array[Rect2] = []
	for region in _regions:
		var rect: Rect2 = _region_rects[region]
		if region.has_method("is_landable_point"):
			islands.append(rect)
			# The island draws its own shallows and surf over the open sea.
			var island_sea := region.get_node_or_null("Terrain/SeaTiles") as CanvasItem
			if island_sea != null:
				island_sea.visible = false
		else:
			land.append(rect)
	terrain.build(land, islands)

func _process(delta: float) -> void:
	_zone_check_left -= delta
	if _zone_check_left > 0.0:
		return
	_zone_check_left = 0.3
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# Regions announce themselves (LocationArea); zones cover the rest.
	if region_at(player.global_position) != null:
		_current_zone = ""
		return
	var zone := zone_at(player.global_position)
	if zone == _current_zone:
		return
	_current_zone = zone
	if zone.is_empty():
		return
	var banner := get_tree().get_first_node_in_group("location_banner") as LocationBanner
	if banner != null:
		banner.show_location(zone)
