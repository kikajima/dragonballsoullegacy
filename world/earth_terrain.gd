class_name EarthTerrain
extends TileMapLayer

# The ground of the open world, painted from assets/world/earth_layout.png
# (one pixel per 32 px tile, built by tools/world/build_earth_layout.py).
# - Sea, rivers and mountains are solid for walkers; flyers pass over them.
# - Cells under a mainland region (West City, Rocky Wastes) are left empty:
#   the region scene draws that ground. Cells around an island region (Kame
#   Island) get water without collision, the island has its own coastline.
# - Forests get trees and mountains get boulders, sorted with WorldDepth.

const DATA = preload("res://world/earth_layout_data.gd")
const TILE := 32
const TURFS := "res://assets/vendor/hu2/Icons/Turfs/"

enum Biome { DEEP, SHALLOW, SAND, GRASS, FOREST, DIRT, MOUNTAIN, SNOW, RIVER, PATH, BRIDGE, CITY, NONE }

const BIOME_COLORS := {
	Biome.DEEP: Color8(24, 64, 140),
	Biome.SHALLOW: Color8(62, 140, 212),
	Biome.SAND: Color8(232, 206, 140),
	Biome.GRASS: Color8(112, 172, 62),
	Biome.FOREST: Color8(42, 112, 44),
	Biome.DIRT: Color8(204, 152, 102),
	Biome.MOUNTAIN: Color8(132, 82, 52),
	Biome.SNOW: Color8(242, 246, 250),
	Biome.RIVER: Color8(84, 164, 232),
	Biome.PATH: Color8(184, 150, 100),
	Biome.BRIDGE: Color8(150, 98, 56),
	Biome.CITY: Color8(192, 192, 198),
}
const BLOCKING := [Biome.DEEP, Biome.SHALLOW, Biome.RIVER, Biome.MOUNTAIN]

var size_tiles := Vector2i.ZERO
var _biomes := PackedByteArray()
# Biome -> [atlas coords] (solid variants) / free-water variants.
var _variants: Dictionary = {}
var _free_water: Array[Vector2i] = []
var _decor: Node2D

static func load_biomes() -> Dictionary:
	var texture := load(DATA.LAYOUT_PATH) as Texture2D
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var lookup := {}
	for biome in BIOME_COLORS:
		lookup[(BIOME_COLORS[biome] as Color).to_rgba32()] = biome
	var size := Vector2i(image.get_width(), image.get_height())
	var biomes := PackedByteArray()
	biomes.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			var colour := image.get_pixel(x, y)
			colour.a = 1.0
			biomes[y * size.x + x] = int(lookup.get(colour.to_rgba32(), Biome.GRASS))
	return {"size": size, "biomes": biomes}

func build(skip_rects: Array[Rect2], island_rects: Array[Rect2]) -> void:
	var layout := load_biomes()
	size_tiles = layout["size"]
	_biomes = layout["biomes"]
	tile_set = _make_tile_set()
	z_as_relative = false
	z_index = -60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_decor = Node2D.new()
	_decor.name = "TerrainDecor"
	add_child(_decor)
	for y in size_tiles.y:
		for x in size_tiles.x:
			var cell_rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if _covered(cell_rect, skip_rects):
				continue
			var biome := biome_at_cell(Vector2i(x, y))
			var hash := _hash(x, y)
			if _covered_any(cell_rect, island_rects):
				set_cell(Vector2i(x, y), 0, _free_water[hash % _free_water.size()])
				continue
			var options: Array = _variants[biome]
			set_cell(Vector2i(x, y), 0, options[hash % options.size()])
			_decorate(biome, Vector2i(x, y), hash)

func biome_at_cell(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= size_tiles.x or cell.y >= size_tiles.y:
		return Biome.DEEP
	return _biomes[cell.y * size_tiles.x + cell.x]

func biome_at(point: Vector2) -> int:
	return biome_at_cell(Vector2i(floori(point.x / TILE), floori(point.y / TILE)))

func is_walkable(point: Vector2) -> bool:
	return not BLOCKING.has(biome_at(point))

func get_decor() -> Node2D:
	return _decor

static func _covered(rect: Rect2, rects: Array[Rect2]) -> bool:
	for other in rects:
		if other.encloses(rect):
			return true
	return false

static func _covered_any(rect: Rect2, rects: Array[Rect2]) -> bool:
	for other in rects:
		if other.intersects(rect):
			return true
	return false

static func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 1000003

# --- tiles -------------------------------------------------------------------

func _make_tile_set() -> TileSet:
	var images: Array[Image] = []
	var solid: Array[bool] = []
	var biome_of: Array[int] = []
	var add := func(image: Image, biome: int, blocks: bool) -> void:
		if image == null:
			return
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
		if image.get_width() != TILE or image.get_height() != TILE:
			image = image.get_region(Rect2i(0, 0, mini(TILE, image.get_width()), mini(TILE, image.get_height())))
			image.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
		images.append(image)
		solid.append(blocks)
		biome_of.append(biome)

	add.call(_turf("NewTurfs", "OWater", Color.WHITE), Biome.DEEP, true)
	add.call(_turf("NewTurfs", "Water", Color.WHITE), Biome.SHALLOW, true)
	add.call(_turf("NewTurfs", "Water", Color(0.9, 1.0, 1.0)), Biome.RIVER, true)
	for image in _sand_tiles():
		add.call(image, Biome.SAND, false)
	for state in ["Grass1", "Grass2", "Grass3", "Grass4"]:
		add.call(_turf("NewTurfs", state, Color.WHITE), Biome.GRASS, false)
	for state in ["DarkGrass1", "DarkGrass2", "DarkGrass3", "DarkGrass4"]:
		add.call(_turf("NewTurfs", state, Color.WHITE), Biome.FOREST, false)
	var dirt := _image("res://assets/sprites/environment/gba_furniture/wastes_ground.png")
	add.call(dirt, Biome.DIRT, false)
	for state in ["Dirt1", "Dirt2"]:
		add.call(_turf("HighwayCliffs", state, Color(0.96, 0.82, 0.66)), Biome.DIRT, false)
	for state in ["M", "T", "B", "BB"]:
		add.call(_turf("HighwayCliffs", state, Color.WHITE), Biome.MOUNTAIN, true)
	for state in ["Snow 1", "Snow 2"]:
		add.call(_turf("NewTurfs", state, Color.WHITE), Biome.SNOW, false)
	for state in ["Path1", "Path2", "Path3"]:
		add.call(_turf("HighwayCliffs", state, Color.WHITE), Biome.PATH, false)
	add.call(_bridge_tile(), Biome.BRIDGE, false)
	add.call(_turf("CityTurfs", "Tile", Color.WHITE), Biome.CITY, false)
	# Water without collision, around islands that build their own shore.
	var free_start := images.size()
	add.call(_turf("NewTurfs", "OWater", Color.WHITE), Biome.NONE, false)

	var columns := 8
	var rows := int(ceil(images.size() / float(columns)))
	var atlas := Image.create(columns * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	for index in images.size():
		atlas.blit_rect(images[index], Rect2i(0, 0, TILE, TILE), Vector2i(index % columns, index / columns) * TILE)

	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	var half := TILE * 0.5
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	_variants.clear()
	_free_water.clear()
	for biome in Biome.values():
		_variants[biome] = []
	for index in images.size():
		var coords := Vector2i(index % columns, index / columns)
		source.create_tile(coords)
		if solid[index]:
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
		if index >= free_start:
			_free_water.append(coords)
		else:
			(_variants[biome_of[index]] as Array).append(coords)
	_variants[Biome.NONE] = _variants[Biome.GRASS]
	return tiles

func _turf(sheet: String, state: String, tint: Color) -> Image:
	var dmi := DmiSpriteSheet.load_file(TURFS + sheet + ".dmi")
	if dmi == null or not dmi.has_state(StringName(state)):
		push_warning("EarthTerrain: missing turf %s/%s" % [sheet, state])
		return null
	var image := dmi.get_frame_texture(StringName(state), &"down", 0).get_image()
	image.convert(Image.FORMAT_RGBA8)
	if tint != Color.WHITE:
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, image.get_pixel(x, y) * tint)
	return image

func _image(path: String) -> Image:
	var texture := load(path) as Texture2D
	return texture.get_image() if texture != null else null

func _sand_tiles() -> Array[Image]:
	var result: Array[Image] = []
	var source := _image("res://assets/tiles/kame_island/sand-light-v1.png")
	if source == null:
		return result
	source = source.duplicate()
	source.resize(TILE * 4, TILE * 4, Image.INTERPOLATE_NEAREST)
	for index in 4:
		result.append(source.get_region(Rect2i(index * TILE, index * TILE, TILE, TILE)))
	return result

func _bridge_tile() -> Image:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color("5d3d22"))
	for x in range(0, TILE, 6):
		image.fill_rect(Rect2i(x, 2, 5, TILE - 4), Color("a77849") if (x / 6) % 2 == 0 else Color("91653e"))
		image.fill_rect(Rect2i(x, 2, 1, TILE - 4), Color("c19863"))
	image.fill_rect(Rect2i(0, 0, TILE, 2), Color("3e2a18"))
	image.fill_rect(Rect2i(0, TILE - 2, TILE, 2), Color("3e2a18"))
	return image

# --- decoration --------------------------------------------------------------

const TREE_TEXTURE := preload("res://assets/vendor/hu2/Icons/Images/Tree.png")
const PALM_TEXTURE := preload("res://assets/vendor/hu2/Icons/Images/PalmTree.png")

func _decorate(biome: int, cell: Vector2i, hash: int) -> void:
	var roll := hash % 100
	var at := Vector2(cell) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	match biome:
		Biome.FOREST:
			# Trees stand on every other cell so the forest still has paths.
			if (cell.x + cell.y) % 2 == 0 and roll < 55:
				_tree(TREE_TEXTURE, at + Vector2((hash % 9) - 4, (hash / 9 % 9) - 4), 0.75 + (hash % 3) * 0.08)
		Biome.GRASS:
			if roll < 3:
				_tree(TREE_TEXTURE, at, 0.6)
		Biome.SAND:
			if roll < 4 and _near(cell, Biome.SHALLOW):
				_tree(PALM_TEXTURE, at, 0.55)

func _near(cell: Vector2i, biome: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if biome_at_cell(cell + offset) == biome:
			return true
	return false

func _tree(texture: Texture2D, foot: Vector2, scale_value: float) -> void:
	var tree := Sprite2D.new()
	tree.texture = texture
	tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tree.scale = Vector2(scale_value, scale_value)
	tree.centered = true
	# Sprite drawn with its trunk base on `foot`.
	tree.position = foot - Vector2(0, texture.get_height() * scale_value * 0.5 - 4)
	_decor.add_child(tree)
	WorldDepth.place(tree, foot.y)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 8)
	shape.shape = box
	body.position = Vector2(0, texture.get_height() * 0.5 - 4 / scale_value)
	body.add_child(shape)
	tree.add_child(body)
