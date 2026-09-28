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
@onready var sand_tiles: Node2D = $Terrain/SandTiles
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

	if sand_textures.is_empty():
		push_warning("Kame Island: Dirt tiles missing from NewTurfs.dmi.")
		return

	for row in range(WORLD_ROWS):
		for column in range(WORLD_COLUMNS):
			var world_position := Vector2(
				float(column * TILE_SIZE + TILE_SIZE / 2),
				float(row * TILE_SIZE + TILE_SIZE / 2)
			)
			_add_tile(
				sea_tiles,
				water_texture,
				world_position,
				-20
			)

			if _is_sand_tile(column, row):
				var texture_index: int = (
					column * 7 + row * 13
				) % sand_textures.size()
				_add_tile(
					sand_tiles,
					sand_textures[texture_index],
					world_position,
					-10
				)

func _build_shore_collision() -> void:
	for row in range(WORLD_ROWS):
		for column in range(WORLD_COLUMNS):
			if _is_sand_tile(column, row):
				continue
			if not _touches_sand(column, row):
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

func _touches_sand(column: int, row: int) -> bool:
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

			if _is_sand_tile(neighbor_x, neighbor_y):
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

func _is_sand_tile(column: int, row: int) -> bool:
	var center := Vector2(14.5, 8.3)
	var point := Vector2(float(column), float(row))
	var normalized := Vector2(
		(point.x - center.x) / 9.2,
		(point.y - center.y) / 5.3
	)

	if normalized.length_squared() > 1.0:
		return false

	# Flatten the lower shoreline slightly so the dock/portal has a natural
	# beach approach.
	if row >= 13 and (column < 10 or column > 19):
		return false

	return true

func _add_tile(
	parent: Node2D,
	texture: Texture2D,
	position_value: Vector2,
	z_value: int
) -> void:
	var tile := Sprite2D.new()
	tile.texture = texture
	tile.position = position_value
	tile.centered = true
	tile.z_index = z_value

	if parent == sand_tiles:
		tile.modulate = Color(1.0, 0.88, 0.62, 1.0)
	elif parent == sea_tiles:
		tile.modulate = Color(0.82, 0.98, 1.0, 1.0)

	parent.add_child(tile)
