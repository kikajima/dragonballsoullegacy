class_name KameIsland
extends Node2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)

const TURF_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Turfs/NewTurfs.dmi"
)
const FLOWERS_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Turfs/Flowers.dmi"
)

const TILE_SIZE: int = 32
const WORLD_COLUMNS: int = 30
const WORLD_ROWS: int = 17
const ISLAND_CENTER := Vector2(480.0, 278.0)

@onready var terrain: Node2D = $Terrain
@onready var sea_tiles: Node2D = $Terrain/SeaTiles
@onready var grass_tiles: Node2D = $Terrain/GrassTiles
@onready var shore_tint: Polygon2D = $Terrain/ShoreTint
@onready var shore_foam_outer: Line2D = $Terrain/ShoreFoamOuter
@onready var shore_foam_inner: Line2D = $Terrain/ShoreFoamInner
@onready var sea_collision: StaticBody2D = $SeaCollision

var _ambient_time: float = 0.0
var _land_silhouette: Polygon2D
var _decorations: Node2D

func _ready() -> void:
	_setup_depth_sorting()
	_setup_organic_coast()
	_build_island_tiles()
	_build_shore_collision()
	_build_flower_patches()
	_polish_layout()

func _process(delta: float) -> void:
	_ambient_time += delta

	var slow_wave: float = (sin(_ambient_time * 1.25) + 1.0) * 0.5
	var fast_wave: float = (sin(_ambient_time * 2.4 + 0.8) + 1.0) * 0.5

	sea_tiles.modulate = Color(
		0.88 + slow_wave * 0.08,
		0.96 + slow_wave * 0.03,
		1.0,
		1.0
	)
	shore_tint.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.22 + slow_wave * 0.18
	)
	shore_foam_outer.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.36 + fast_wave * 0.42
	)
	shore_foam_inner.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.18 + slow_wave * 0.28
	)

func _setup_depth_sorting() -> void:
	# The previous fixed z-index values forced the house to draw over Roshi.
	# Y-sort lets characters naturally pass in front of or behind scenery.
	y_sort_enabled = true

	_set_canvas_z(&"KameHouse/Sprite2D", 0)
	_set_canvas_z(&"PalmTreeLeft", 0)
	_set_canvas_z(&"PalmTreeRight", 0)
	_set_canvas_z(&"PalmTreeSouth", 0)
	_set_canvas_z(&"PalmTreeNorthWest", 0)
	_set_canvas_z(&"PalmTreeNorthEast", 0)
	_set_canvas_z(&"BeachUmbrella", 0)
	_set_canvas_z(&"BeachChair", 0)
	_set_canvas_z(&"TravelCapsule", 0)
	_set_canvas_z(&"TrainingRing", -1)

func _set_canvas_z(node_path: StringName, value: int) -> void:
	var item: CanvasItem = get_node_or_null(
		NodePath(String(node_path))
	) as CanvasItem
	if item != null:
		item.z_index = value

func _setup_organic_coast() -> void:
	_land_silhouette = Polygon2D.new()
	_land_silhouette.name = "LandSilhouette"
	_land_silhouette.polygon = _coast_points()
	_land_silhouette.color = Color(0.34, 0.54, 0.08, 1.0)
	_land_silhouette.z_index = -10
	terrain.add_child(_land_silhouette)
	terrain.move_child(_land_silhouette, 1)

	# A larger translucent shape creates shallow water without exposing the
	# square edges of the grass tile mask.
	shore_tint.polygon = _scaled_coast_points(1.045)
	shore_tint.color = Color(0.34, 0.86, 0.94, 0.34)
	shore_tint.z_index = -11

	shore_foam_outer.points = _closed_points(
		_scaled_coast_points(1.025)
	)
	shore_foam_outer.width = 3.0
	shore_foam_outer.z_index = -7

	shore_foam_inner.points = _closed_points(
		_scaled_coast_points(0.992)
	)
	shore_foam_inner.width = 1.5
	shore_foam_inner.z_index = -6

func _coast_points() -> PackedVector2Array:
	# Hand-shaped after the Buu's Fury Kame Island reference. More points and
	# gentler turns hide the grid/hexagon feel of the old procedural outline.
	return PackedVector2Array([
		Vector2(154, 272),
		Vector2(160, 230),
		Vector2(176, 191),
		Vector2(203, 157),
		Vector2(239, 132),
		Vector2(284, 111),
		Vector2(337, 98),
		Vector2(393, 90),
		Vector2(451, 86),
		Vector2(511, 89),
		Vector2(569, 98),
		Vector2(624, 114),
		Vector2(672, 137),
		Vector2(710, 167),
		Vector2(741, 203),
		Vector2(760, 244),
		Vector2(769, 286),
		Vector2(766, 329),
		Vector2(753, 368),
		Vector2(730, 404),
		Vector2(696, 433),
		Vector2(652, 456),
		Vector2(601, 470),
		Vector2(546, 478),
		Vector2(490, 481),
		Vector2(433, 478),
		Vector2(378, 470),
		Vector2(326, 456),
		Vector2(279, 435),
		Vector2(237, 407),
		Vector2(204, 374),
		Vector2(179, 338),
		Vector2(162, 303),
	])

func _scaled_coast_points(scale_value: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in _coast_points():
		result.append(
			ISLAND_CENTER
			+ (point - ISLAND_CENTER) * scale_value
		)
	return result

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result

func _build_island_tiles() -> void:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(TURF_DMI_PATH)
	if dmi == null:
		push_warning("Kame Island: NewTurfs.dmi could not be loaded.")
		return

	var water_texture: Texture2D = dmi.get_frame_texture(
		&"Water",
		&"down",
		0
	)
	if water_texture == null:
		push_warning("Kame Island: Water tile missing from NewTurfs.dmi.")
		return

	var grass_textures: Array[Texture2D] = []
	for state_name in [
		&"DarkGrass1",
		&"DarkGrass2",
		&"DarkGrass3",
		&"DarkGrass4",
	]:
		var texture: Texture2D = dmi.get_frame_texture(
			state_name,
			&"down",
			0
		)
		if texture != null:
			grass_textures.append(texture)

	if grass_textures.is_empty():
		push_warning("Kame Island: DarkGrass tiles missing from NewTurfs.dmi.")
		return

	for row in range(WORLD_ROWS):
		for column in range(WORLD_COLUMNS):
			var world_position: Vector2 = Vector2(
				float(column * TILE_SIZE + TILE_SIZE / 2),
				float(row * TILE_SIZE + TILE_SIZE / 2)
			)

			_add_tile(
				sea_tiles,
				water_texture,
				world_position,
				-20,
				Color(0.84, 0.97, 1.0, 1.0)
			)

			# Grass tiles intentionally stop before the organic coastline.
			# The LandSilhouette fills that rim, hiding the square tile steps.
			if not _is_grass_tile(column, row):
				continue

			# Keep the island on one coherent base turf. The alternate DarkGrass
			# variants contain decorative clutter that reads as scattered rocks.
			var grass_index: int = 0

			_add_tile(
				grass_tiles,
				grass_textures[grass_index],
				world_position,
				-9,
				Color(1.0, 1.0, 1.0, 1.0)
			)

func _is_grass_tile(column: int, row: int) -> bool:
	var center := Vector2(14.5, 8.25)
	var point := Vector2(float(column), float(row))
	var normalized := Vector2(
		(point.x - center.x) / 8.05,
		(point.y - center.y) / 4.8
	)
	return normalized.length_squared() <= 1.0

func _build_shore_collision() -> void:
	for row in range(WORLD_ROWS):
		for column in range(WORLD_COLUMNS):
			if _is_island_tile(column, row):
				continue
			if not _touches_island(column, row):
				continue
			if _is_dock_opening(column, row):
				continue

			var shape: RectangleShape2D = RectangleShape2D.new()
			shape.size = Vector2(TILE_SIZE, TILE_SIZE)

			var collision: CollisionShape2D = CollisionShape2D.new()
			collision.shape = shape
			collision.position = Vector2(
				float(column * TILE_SIZE + TILE_SIZE / 2),
				float(row * TILE_SIZE + TILE_SIZE / 2)
			)
			sea_collision.add_child(collision)

func _touches_island(column: int, row: int) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue

			var neighbor_x: int = column + offset_x
			var neighbor_y: int = row + offset_y
			if (
				neighbor_x < 0
				or neighbor_y < 0
				or neighbor_x >= WORLD_COLUMNS
				or neighbor_y >= WORLD_ROWS
			):
				continue

			if _is_island_tile(neighbor_x, neighbor_y):
				return true

	return false

func _is_dock_opening(column: int, row: int) -> bool:
	return (
		column >= 22
		and column <= 25
		and row >= 12
		and row <= 14
	)

func _is_island_tile(column: int, row: int) -> bool:
	# Collision remains tile-based but is now smooth and regular. The organic
	# visual coastline above masks the unavoidable physics grid underneath.
	var center := Vector2(14.5, 8.25)
	var point := Vector2(float(column), float(row))
	var normalized := Vector2(
		(point.x - center.x) / 9.0,
		(point.y - center.y) / 5.55
	)

	if normalized.length_squared() > 1.0:
		return false

	if row >= 13 and (column < 7 or column > 24):
		return false

	return true

func _build_flower_patches() -> void:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(FLOWERS_DMI_PATH)
	if dmi == null:
		return

	var flower_state: StringName = &""
	if not dmi.has_state(flower_state):
		var state_keys: Array = dmi.states.keys()
		if state_keys.is_empty():
			return
		flower_state = StringName(String(state_keys[0]))

	var frame_count: int = dmi.get_frame_count(flower_state)
	if frame_count <= 0:
		return

	_decorations = Node2D.new()
	_decorations.name = "FlowerPatches"
	_decorations.z_index = -1
	add_child(_decorations)

	var positions: Array[Vector2] = [
		Vector2(350, 220),
		Vector2(395, 288),
		Vector2(548, 186),
		Vector2(590, 286),
		Vector2(428, 410),
		Vector2(682, 338),
		Vector2(278, 322),
		Vector2(535, 420),
	]

	for index in range(positions.size()):
		var frame_index: int = index % frame_count
		var texture: Texture2D = dmi.get_frame_texture(
			flower_state,
			&"down",
			frame_index
		)
		if texture == null:
			continue

		var flower: Sprite2D = Sprite2D.new()
		flower.texture = texture
		flower.position = positions[index]
		flower.scale = Vector2(0.78, 0.78)
		_decorations.add_child(flower)

func _polish_layout() -> void:
	# House: smaller and higher so it remains the focal point without hiding
	# Roshi or consuming most of the playable foreground.
	_set_node_transform(
		&"KameHouse",
		Vector2(480, 222),
		Vector2(0.82, 0.82)
	)
	_set_node_position(&"KameHouseEntrance", Vector2(482, 338))

	# Mentor/NPC cluster is pulled forward and left of the house entrance.
	_set_node_position(&"MasterRoshi", Vector2(365, 390))
	_set_node_position(&"Turtle", Vector2(302, 408))

	# Sparring gets its own readable area to the right.
	_set_node_position(&"TrainingFighter", Vector2(650, 382))
	var ring: Line2D = get_node_or_null("TrainingRing") as Line2D
	if ring != null:
		ring.points = PackedVector2Array([
			Vector2(585, 344),
			Vector2(704, 344),
			Vector2(724, 382),
			Vector2(704, 420),
			Vector2(585, 420),
			Vector2(565, 382),
			Vector2(585, 344),
		])

	# Tropical props frame the island instead of competing with the house.
	_set_node_position(&"PalmTreeLeft", Vector2(282, 286))
	_set_node_position(&"PalmTreeRight", Vector2(690, 292))
	_set_node_position(&"PalmTreeSouth", Vector2(616, 438))
	_set_node_position(&"BeachUmbrella", Vector2(248, 405))
	_set_node_position(&"BeachChair", Vector2(208, 430))

	# Keep the tutorial/checkpoint readable but out of Roshi's foreground.
	_set_node_position(&"BeachGuide", Vector2(438, 452))
	_set_node_position(&"IslandCheckpoint", Vector2(510, 452))

	# Dock/travel capsule remains in the southeast corner.
	_set_node_position(&"Dock", Vector2(790, 468))
	_set_node_position(&"TravelCapsule", Vector2(836, 450))
	_set_node_position(&"WestCityBoat", Vector2(792, 444))

func _set_node_position(node_path: StringName, value: Vector2) -> void:
	var node: Node2D = get_node_or_null(
		NodePath(String(node_path))
	) as Node2D
	if node != null:
		node.position = value

func _set_node_transform(
	node_path: StringName,
	position_value: Vector2,
	scale_value: Vector2
) -> void:
	var node: Node2D = get_node_or_null(
		NodePath(String(node_path))
	) as Node2D
	if node == null:
		return

	node.position = position_value
	node.scale = scale_value

func _add_tile(
	parent: Node2D,
	texture: Texture2D,
	position_value: Vector2,
	z_value: int,
	color_value: Color
) -> void:
	var tile: Sprite2D = Sprite2D.new()
	tile.texture = texture
	tile.position = position_value
	tile.centered = true
	tile.z_index = z_value
	tile.modulate = color_value
	parent.add_child(tile)
