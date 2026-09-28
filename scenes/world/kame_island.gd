class_name KameIsland
extends Node2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)

const TURF_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Turfs/NewTurfs.dmi"
)
const TILE_SIZE: int = 32
const WORLD_COLUMNS: int = 30
const WORLD_ROWS: int = 17

@onready var sea_tiles: Node2D = $Terrain/SeaTiles
@onready var beach_tiles: Node2D = $Terrain/BeachTiles
@onready var grass_tiles: Node2D = $Terrain/GrassTiles
@onready var shore_tint: Polygon2D = $Terrain/ShoreTint
@onready var shore_foam_outer: Line2D = $Terrain/ShoreFoamOuter
@onready var shore_foam_inner: Line2D = $Terrain/ShoreFoamInner
@onready var sea_collision: StaticBody2D = $SeaCollision

var _ambient_time: float = 0.0

func _ready() -> void:
	_build_island_tiles()
	_build_shore_collision()

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
		0.62 + slow_wave * 0.28
	)
	shore_foam_outer.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.42 + fast_wave * 0.48
	)
	shore_foam_inner.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.22 + slow_wave * 0.38
	)

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

	var sand_textures: Array[Texture2D] = []
	for state_name in [&"Dirt1", &"Dirt2", &"Dirt3", &"Dirt4"]:
		var texture: Texture2D = dmi.get_frame_texture(
			state_name,
			&"down",
			0
		)
		if texture != null:
			sand_textures.append(texture)

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

	if sand_textures.is_empty():
		push_warning("Kame Island: Dirt tiles missing from NewTurfs.dmi.")
		return

	if grass_textures.is_empty():
		push_warning(
			"Kame Island: DarkGrass tiles missing; using tinted Dirt fallback."
		)
		grass_textures = sand_textures.duplicate()

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

			if not _is_island_tile(column, row):
				continue

			var texture_index: int = (
				column * 7 + row * 13
			) % sand_textures.size()

			if _is_beach_tile(column, row):
				_add_tile(
					beach_tiles,
					sand_textures[texture_index],
					world_position,
					-10,
					Color(1.0, 0.91, 0.72, 1.0)
				)
				continue

			var grass_index: int = (
				column * 11 + row * 5
			) % grass_textures.size()

			_add_tile(
				grass_tiles,
				grass_textures[grass_index],
				world_position,
				-9,
				Color(1.0, 1.0, 1.0, 1.0)
			)

func _build_shore_collision() -> void:
	for row in range(WORLD_ROWS):
		for column in range(WORLD_COLUMNS):
			if _is_island_tile(column, row):
				continue
			if not _touches_island(column, row):
				continue
			if _is_dock_opening(column, row):
				continue

			var shape := RectangleShape2D.new()
			shape.size = Vector2(TILE_SIZE, TILE_SIZE)

			var collision := CollisionShape2D.new()
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
	# Preserve a narrow southeast opening for the dock/travel capsule.
	return (
		column >= 22
		and column <= 25
		and row >= 12
		and row <= 14
	)

func _is_island_tile(column: int, row: int) -> bool:
	var center := Vector2(14.5, 8.25)
	var point := Vector2(float(column), float(row))
	var normalized := Vector2(
		(point.x - center.x) / 8.9,
		(point.y - center.y) / 5.65
	)

	var radial: float = normalized.length_squared()
	if radial > 1.0:
		return false

	# Break up the ellipse slightly so the coastline feels more like the
	# irregular Buu's Fury island rather than a perfect geometric oval.
	var coast_noise: int = (
		column * 17
		+ row * 23
		+ column * row * 3
	) % 11

	if radial > 0.78 and coast_noise <= 1:
		return false

	# Southeast beach/dock approach.
	if row >= 13 and (column < 7 or column > 24):
		return false

	return true

func _is_beach_tile(column: int, row: int) -> bool:
	if not _is_island_tile(column, row):
		return false

	# Any land tile touching sea becomes beach. Add a second irregular ring
	# in selected places so the beach width varies naturally.
	if _touches_open_water(column, row):
		return true

	var center := Vector2(14.5, 8.25)
	var point := Vector2(float(column), float(row))
	var normalized := Vector2(
		(point.x - center.x) / 8.9,
		(point.y - center.y) / 5.65
	)

	var radial: float = normalized.length_squared()
	var variation: int = (column * 5 + row * 7) % 9
	return radial >= 0.57 and variation <= 4

func _touches_open_water(column: int, row: int) -> bool:
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
				return true

			if not _is_island_tile_raw(neighbor_x, neighbor_y):
				return true

	return false

func _is_island_tile_raw(column: int, row: int) -> bool:
	var center := Vector2(14.5, 8.25)
	var point := Vector2(float(column), float(row))
	var normalized := Vector2(
		(point.x - center.x) / 8.9,
		(point.y - center.y) / 5.65
	)

	if normalized.length_squared() > 1.0:
		return false

	if row >= 13 and (column < 7 or column > 24):
		return false

	return true

func _add_tile(
	parent: Node2D,
	texture: Texture2D,
	position_value: Vector2,
	z_value: int,
	color_value: Color
) -> void:
	var tile := Sprite2D.new()
	tile.texture = texture
	tile.position = position_value
	tile.centered = true
	tile.z_index = z_value
	tile.modulate = color_value
	parent.add_child(tile)
