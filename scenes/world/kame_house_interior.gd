class_name KameHouseInterior
extends Node2D

const DMI_SPRITE_SHEET_SCRIPT = preload(
	"res://core/assets/dmi_sprite_sheet.gd"
)
const FLOOR_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Turfs/NewTurfs.dmi"
)
const WALL_DMI_PATH := (
	"res://assets/vendor/hu2/Icons/Turfs/ApartmentInts.dmi"
)
const TILE_SIZE: int = 32

@onready var floor_tiles: Node2D = $Terrain/FloorTiles
@onready var wall_tiles: Node2D = $Terrain/WallTiles

func _ready() -> void:
	_build_floor()
	_build_walls()

func _build_floor() -> void:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(FLOOR_DMI_PATH)
	if dmi == null:
		return

	var state: StringName = &"Tile"
	if not dmi.has_state(state):
		state = &"GrayTile"
	if not dmi.has_state(state):
		return

	var texture: Texture2D = dmi.get_frame_texture(
		state,
		&"down",
		0
	)
	if texture == null:
		return

	for row in range(8):
		for column in range(12):
			_add_tile(
				floor_tiles,
				texture,
				Vector2(
					float(96 + column * TILE_SIZE),
					float(80 + row * TILE_SIZE)
				),
				Color(1.0, 0.91, 0.86, 1.0),
				-10
			)

func _build_walls() -> void:
	var dmi = DMI_SPRITE_SHEET_SCRIPT.load_file(WALL_DMI_PATH)
	if dmi == null or not dmi.has_state(&"BaseWall"):
		return

	var texture: Texture2D = dmi.get_frame_texture(
		&"BaseWall",
		&"down",
		0
	)
	if texture == null:
		return

	for column in range(14):
		_add_tile(
			wall_tiles,
			texture,
			Vector2(
				float(64 + column * TILE_SIZE),
				48.0
			),
			Color(1.0, 0.72, 0.78, 1.0),
			-5
		)

func _add_tile(
	parent: Node2D,
	texture: Texture2D,
	position_value: Vector2,
	color_value: Color,
	z_value: int
) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = position_value
	sprite.modulate = color_value
	sprite.z_index = z_value
	parent.add_child(sprite)
