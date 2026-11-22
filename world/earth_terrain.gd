class_name EarthTerrain
extends TileMapLayer

# The ground of the open world, painted from assets/world/earth_layout.png
# (one pixel per 32 px tile, built by tools/world/build_earth_layout.py).
# - Sea, rivers and mountains are solid for walkers; flyers pass over them.
# - Cells under a mainland region (West City, Rocky Wastes) are left empty:
#   the region scene draws that ground. Cells around an island region (Kame
#   Island) get water without collision, the island has its own coastline.
#
# Tiles follow the rules of the HU2 world map (Icons/Map.dmm), studied with
# tools/world/render_dmm_crop.gd:
# - Grass is the land. A tile next to grass (water, dirt, sand, snow, road)
#   gets the grass fuzz on that side (GrassFuzzL/R/T/B), a tuft when the
#   grass only touches a corner, and a rounded grass corner (DarkGrassTL...)
#   when grass is on two sides.
# - Where land stands north of water, the shore is a two tile cliff:
#   TM on the land, BM on the water, ML/BL and MR/BR at the ends and a small
#   TL/TR lip above them. The cliff top is solid.
# - Mountains are rock walls in order: T on the top row, M inside, B and BB
#   on the two rows above their foot, and a rock rim (CliffL/CliffR) on the
#   ground beside them.

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
const WATER := [Biome.DEEP, Biome.SHALLOW, Biome.RIVER]
const GRASSY := [Biome.GRASS, Biome.FOREST]
# Land that can stand as a cliff over water.
const CLIFF_LAND := [Biome.GRASS, Biome.FOREST, Biome.DIRT, Biome.SNOW]

# Cell kinds outside the plain layout.
const CELL_NORMAL := 0
const CELL_REGION := 1 # drawn by a region scene
const CELL_ISLAND_SEA := 2 # open water around an island region

var size_tiles := Vector2i.ZERO
var _biomes := PackedByteArray()
var _kind := PackedByteArray()
# 1 on cliff tops (solid land).
var _cliff := PackedByteArray()
# Cell index -> cliff overlay states (NewCliffs), drawn above the fuzz.
var _cliff_layers: Dictionary = {}
var _decor: Node2D
var _sheets: Dictionary = {}
var _layer_images: Dictionary = {}

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
	_kind.resize(size_tiles.x * size_tiles.y)
	_cliff.resize(size_tiles.x * size_tiles.y)
	_kind.fill(CELL_NORMAL)
	_cliff.fill(0)
	for y in size_tiles.y:
		for x in size_tiles.x:
			var cell_rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if _covered(cell_rect, skip_rects):
				_kind[y * size_tiles.x + x] = CELL_REGION
			elif _covered_any(cell_rect, island_rects):
				_kind[y * size_tiles.x + x] = CELL_ISLAND_SEA
	_plan_cliffs()

	# Every cell is a stack of layers; equal stacks share one atlas tile.
	var stacks: Dictionary = {} # stack key -> atlas index
	var stack_layers: Array = []
	var stack_solid: Array[bool] = []
	var cell_stack := PackedInt32Array()
	cell_stack.resize(size_tiles.x * size_tiles.y)
	var region_edges: Dictionary = {} # cell -> stack
	for y in size_tiles.y:
		for x in size_tiles.x:
			var index := y * size_tiles.x + x
			cell_stack[index] = -1
			var cell := Vector2i(x, y)
			var layers: Array
			var solid := false
			if _kind[index] == CELL_REGION:
				# The region draws this ground; only the grass of the
				# Earth around it spills over its border.
				layers = _grass_edges(cell)
				if layers.is_empty():
					continue
			else:
				layers = _layers_for(cell)
				solid = _kind[index] != CELL_ISLAND_SEA and not is_walkable_cell(cell)
			var key := "|".join(layers) + ("#" if solid else "")
			if not stacks.has(key):
				stacks[key] = stack_layers.size()
				stack_layers.append(layers)
				stack_solid.append(solid)
			if _kind[index] == CELL_REGION:
				region_edges[cell] = stacks[key]
			else:
				cell_stack[index] = stacks[key]
	tile_set = _make_tile_set(stack_layers, stack_solid)
	z_as_relative = false
	z_index = -60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var columns := _atlas_columns(stack_layers.size())
	for y in size_tiles.y:
		for x in size_tiles.x:
			var stack := cell_stack[y * size_tiles.x + x]
			if stack >= 0:
				set_cell(Vector2i(x, y), 0, Vector2i(stack % columns, stack / columns))
	# Above the regions' own ground polygons, below everything on it.
	var edges := TileMapLayer.new()
	edges.name = "RegionEdges"
	edges.tile_set = tile_set
	edges.z_as_relative = false
	edges.z_index = 1
	edges.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	edges.collision_enabled = false
	for cell: Vector2i in region_edges:
		var stack: int = region_edges[cell]
		edges.set_cell(cell, 0, Vector2i(stack % columns, stack / columns))
	add_child(edges)
	_decor = Node2D.new()
	_decor.name = "TerrainDecor"
	add_child(_decor)
	for y in size_tiles.y:
		for x in size_tiles.x:
			if _kind[y * size_tiles.x + x] == CELL_NORMAL and _cliff[y * size_tiles.x + x] == 0:
				_decorate(biome_at_cell(Vector2i(x, y)), Vector2i(x, y), _hash(x, y))

func biome_at_cell(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= size_tiles.x or cell.y >= size_tiles.y:
		return Biome.DEEP
	return _biomes[cell.y * size_tiles.x + cell.x]

func biome_at(point: Vector2) -> int:
	return biome_at_cell(_cell_of(point))

func is_walkable(point: Vector2) -> bool:
	return is_walkable_cell(_cell_of(point))

func is_walkable_cell(cell: Vector2i) -> bool:
	if BLOCKING.has(biome_at_cell(cell)):
		return false
	return not is_cliff_cell(cell)

# Cliff tops over the water are solid.
func is_cliff_cell(cell: Vector2i) -> bool:
	if not _inside(cell):
		return false
	return _cliff[cell.y * size_tiles.x + cell.x] == 1

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

func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_tiles.x and cell.y < size_tiles.y

func _kind_at(cell: Vector2i) -> int:
	return _kind[cell.y * size_tiles.x + cell.x] if _inside(cell) else CELL_NORMAL

# Plain layout water (not the free sea around an island).
func _is_water(cell: Vector2i) -> bool:
	return WATER.has(biome_at_cell(cell)) and _kind_at(cell) == CELL_NORMAL

func _is_open_water(cell: Vector2i) -> bool:
	return _is_water(cell) and biome_at_cell(cell) != Biome.RIVER

func _is_grass(cell: Vector2i) -> bool:
	return _inside(cell) and _kind_at(cell) == CELL_NORMAL and GRASSY.has(biome_at_cell(cell))

func _is_mountain(cell: Vector2i) -> bool:
	return _inside(cell) and biome_at_cell(cell) == Biome.MOUNTAIN

# --- cliffs over water -----------------------------------------------------------

func _plan_cliffs() -> void:
	var tops: Dictionary = {}
	for y in size_tiles.y - 2:
		for x in size_tiles.x:
			var cell := Vector2i(x, y)
			if _kind_at(cell) != CELL_NORMAL or not CLIFF_LAND.has(biome_at_cell(cell)):
				continue
			# Two rows of sea or lake below: the face (BM) and open water
			# under it. Rivers are too narrow for a cliff.
			if _is_open_water(cell + Vector2i.DOWN) and _is_open_water(cell + Vector2i(0, 2)):
				tops[cell] = true
	# A cliff shorter than three tiles reads as a stray rock: drop it.
	for cell: Vector2i in tops.keys():
		var run := 1
		var step := cell + Vector2i.LEFT
		while tops.has(step):
			run += 1
			step += Vector2i.LEFT
		step = cell + Vector2i.RIGHT
		while tops.has(step):
			run += 1
			step += Vector2i.RIGHT
		if run < 3:
			tops[cell] = false
	for cell: Vector2i in tops.keys():
		if not tops[cell]:
			tops.erase(cell)
	for cell: Vector2i in tops:
		var index := cell.y * size_tiles.x + cell.x
		_cliff[index] = 1
		var left := not tops.has(cell + Vector2i.LEFT)
		var right := not tops.has(cell + Vector2i.RIGHT)
		var base := cell + Vector2i.DOWN
		var top_state := "TM%d" % (2 + _hash(cell.x, cell.y) % 2)
		var base_state := "BM%d" % (1 + _hash(base.x, base.y) % 3)
		if left and not right:
			top_state = "ML"
			base_state = "BL"
		elif right and not left:
			top_state = "MR"
			base_state = "BR"
		_add_cliff_layer(cell, top_state)
		_add_cliff_layer(base, base_state)
		# The lip where a side wall meets the land above it.
		var above := cell + Vector2i.UP
		if top_state in ["ML", "MR"] and _inside(above) and not tops.has(above) and CLIFF_LAND.has(biome_at_cell(above)) and _kind_at(above) == CELL_NORMAL:
			_add_cliff_layer(above, "TL" if top_state == "ML" else "TR")

func _add_cliff_layer(cell: Vector2i, state: String) -> void:
	var index := cell.y * size_tiles.x + cell.x
	if not _cliff_layers.has(index):
		_cliff_layers[index] = []
	(_cliff_layers[index] as Array).append("NewCliffs:" + state)

# --- layers of one cell --------------------------------------------------------------

func _layers_for(cell: Vector2i) -> Array:
	var index := cell.y * size_tiles.x + cell.x
	var hash := _hash(cell.x, cell.y)
	if _kind[index] == CELL_ISLAND_SEA:
		return ["NewTurfs:OWater"]
	var biome := biome_at_cell(cell)
	var layers: Array = []
	match biome:
		Biome.DEEP, Biome.SHALLOW:
			layers.append("NewTurfs:OWater")
		Biome.RIVER:
			layers.append("NewTurfs:Water")
		Biome.GRASS, Biome.FOREST:
			layers.append("NewTurfs:DarkGrass%d" % (1 + hash % 4))
		Biome.SAND:
			layers.append("sand:%d" % (hash % 4))
		Biome.DIRT, Biome.PATH:
			layers.append("HighwayCliffs:Dirt%d" % (1 + hash % 4))
		Biome.SNOW:
			layers.append("NewTurfs:Snow %d" % (1 + hash % 2))
		Biome.CITY:
			layers.append("CityTurfs:Tile")
		Biome.BRIDGE:
			layers.append("NewTurfs:Water")
			layers.append("bridge")
		Biome.MOUNTAIN:
			layers.append_array(_mountain_layers(cell))
	if not GRASSY.has(biome) and biome != Biome.MOUNTAIN and biome != Biome.BRIDGE:
		layers.append_array(_grass_edges(cell))
	if biome != Biome.MOUNTAIN:
		if _is_mountain(cell + Vector2i.LEFT):
			layers.append("HighwayCliffs:CliffL")
		if _is_mountain(cell + Vector2i.RIGHT):
			layers.append("HighwayCliffs:CliffR")
	if _cliff_layers.has(index):
		layers.append_array(_cliff_layers[index])
	return layers

# Mountains are terraces of rock walls seen from the south, like the HU2
# highway cliffs: T at the top of each wall, M inside, B and BB at its foot,
# and dirt ledges between walls with a rock rim at their sides.
func _mountain_layers(cell: Vector2i) -> Array:
	if _is_ledge(cell):
		var ledge: Array = ["HighwayCliffs:Dirt%d" % (1 + _hash(cell.x, cell.y) % 4)]
		if _is_rock(cell + Vector2i.LEFT):
			ledge.append("HighwayCliffs:CliffL")
		if _is_rock(cell + Vector2i.RIGHT):
			ledge.append("HighwayCliffs:CliffR")
		return ledge
	var up := cell + Vector2i.UP
	if not _is_rock(up):
		# T has a jagged top: the ground behind shows through.
		var behind := "NewTurfs:Snow 1" if biome_at_cell(up) == Biome.SNOW else "HighwayCliffs:Dirt1"
		return [behind, "HighwayCliffs:T"]
	if not _is_rock(cell + Vector2i.DOWN):
		return ["HighwayCliffs:BB"]
	if not _is_rock(cell + Vector2i(0, 2)):
		return ["HighwayCliffs:B"]
	return ["HighwayCliffs:M"]

const TERRACE_ROWS := 7
const TERRACE_STEP := 5

# A ledge row inside a mountain, away from its top and foot. The rows step
# up and down every few columns so the walls zigzag.
func _is_ledge(cell: Vector2i) -> bool:
	if not _is_mountain(cell):
		return false
	var offset := _hash(floori(cell.x / float(TERRACE_STEP)), 77) % TERRACE_ROWS
	# Ledges are two rows deep: row 0 and row 1 of each terrace.
	var row := posmod(cell.y + offset, TERRACE_ROWS)
	if row > 1:
		return false
	var top := cell.y - row
	for y in range(top - 2, top + 5):
		if not _is_mountain(Vector2i(cell.x, y)):
			return false
	return true

func _is_rock(cell: Vector2i) -> bool:
	return _is_mountain(cell) and not _is_ledge(cell)

func _grass_edges(cell: Vector2i) -> Array:
	var n := _is_grass(cell + Vector2i.UP)
	var s := _is_grass(cell + Vector2i.DOWN)
	var w := _is_grass(cell + Vector2i.LEFT)
	var e := _is_grass(cell + Vector2i.RIGHT)
	# A cliff face already covers the top of its base tile.
	var index := cell.y * size_tiles.x + cell.x
	if _cliff_layers.has(index) and is_cliff_cell(cell + Vector2i.UP):
		n = false
	var edges: Array = []
	# Grass on two sides rounds the corner off.
	if n and e and not s and not w:
		return ["NewTurfs:DarkGrassBL"]
	if n and w and not s and not e:
		return ["NewTurfs:DarkGrassBR"]
	if s and e and not n and not w:
		return ["NewTurfs:DarkGrassTL"]
	if s and w and not n and not e:
		return ["NewTurfs:DarkGrassTR"]
	if n:
		edges.append("NewTurfs:GrassFuzzB")
	if s:
		edges.append("NewTurfs:GrassFuzzT")
	if w:
		edges.append("NewTurfs:GrassFuzzR")
	if e:
		edges.append("NewTurfs:GrassFuzzL")
	# Tufts where grass only touches a corner.
	if not n and not e and _is_grass(cell + Vector2i(1, -1)):
		edges.append("NewTurfs:GrassFuzzTR")
	if not n and not w and _is_grass(cell + Vector2i(-1, -1)):
		edges.append("NewTurfs:GrassFuzzTL")
	if not s and not e and _is_grass(cell + Vector2i(1, 1)):
		edges.append("NewTurfs:GrassFuzzBR")
	if not s and not w and _is_grass(cell + Vector2i(-1, 1)):
		edges.append("NewTurfs:GrassFuzzBL")
	return edges

# --- tiles ---------------------------------------------------------------------

static func _atlas_columns(count: int) -> int:
	return maxi(8, ceili(sqrt(float(count))))

func _make_tile_set(stack_layers: Array, stack_solid: Array[bool]) -> TileSet:
	var columns := _atlas_columns(stack_layers.size())
	var rows := ceili(stack_layers.size() / float(columns))
	var atlas := Image.create(columns * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	for index in stack_layers.size():
		var origin := Vector2i(index % columns, index / columns) * TILE
		for layer in stack_layers[index]:
			var image := _layer_image(str(layer))
			if image != null:
				atlas.blend_rect(image, Rect2i(0, 0, TILE, TILE), origin)

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
	for index in stack_layers.size():
		var coords := Vector2i(index % columns, index / columns)
		source.create_tile(coords)
		if stack_solid[index]:
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return tiles

# "Sheet:State" from the HU2 turfs, or one of the drawn tiles.
func _layer_image(layer: String) -> Image:
	if _layer_images.has(layer):
		return _layer_images[layer]
	var image: Image = null
	if layer.begins_with("sand:"):
		var sand := _sand_tiles()
		if not sand.is_empty():
			image = sand[int(layer.get_slice(":", 1)) % sand.size()]
	elif layer == "bridge":
		image = _bridge_tile()
	else:
		image = _turf(layer.get_slice(":", 0), layer.get_slice(":", 1))
	if image != null:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
		if image.get_size() != Vector2i(TILE, TILE):
			image = image.get_region(Rect2i(0, 0, mini(TILE, image.get_width()), mini(TILE, image.get_height())))
			image.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	_layer_images[layer] = image
	return image

func _turf(sheet: String, state: String) -> Image:
	if not _sheets.has(sheet):
		_sheets[sheet] = DmiSpriteSheet.load_file(TURFS + sheet + ".dmi")
	var dmi: DmiSpriteSheet = _sheets[sheet]
	if dmi == null or not dmi.has_state(StringName(state)):
		push_warning("EarthTerrain: missing turf %s/%s" % [sheet, state])
		return null
	return dmi.get_frame_texture(StringName(state), &"down", 0).get_image()

func _image(path: String) -> Image:
	var texture := load(path) as Texture2D
	return texture.get_image() if texture != null else null

var _sand_cache: Array[Image] = []

func _sand_tiles() -> Array[Image]:
	if not _sand_cache.is_empty():
		return _sand_cache
	var source := _image("res://assets/tiles/kame_island/sand-light-v1.png")
	if source == null:
		return _sand_cache
	source = source.duplicate()
	source.resize(TILE * 4, TILE * 4, Image.INTERPOLATE_NEAREST)
	for index in 4:
		_sand_cache.append(source.get_region(Rect2i(index * TILE, index * TILE, TILE, TILE)))
	return _sand_cache

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
const ROCK_TEXTURE := preload("res://assets/vendor/hu2/Icons/Images/RockSlide.png")

func _decorate(biome: int, cell: Vector2i, hash: int) -> void:
	var roll := hash % 100
	var at := Vector2(cell) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	match biome:
		Biome.FOREST:
			# Trees stand on every other cell so the forest still has paths.
			if (cell.x + cell.y) % 2 == 0 and roll < 55:
				_tree(TREE_TEXTURE, at + Vector2((hash % 9) - 4, (hash / 9 % 9) - 4), 0.75 + (hash % 3) * 0.08)
		Biome.GRASS:
			if roll < 3 and not _near_water(cell):
				_tree(TREE_TEXTURE, at, 0.6)
		Biome.SAND:
			if roll < 6 and _near_water(cell):
				_tree(PALM_TEXTURE, at, 0.55)
		Biome.DIRT:
			# Scattered boulders, never on a path or by the water.
			if roll < 2 and hash % 7 == 0 and not _near_water(cell):
				_rock(at, 0.42 + (hash % 3) * 0.06)

func _near_water(cell: Vector2i) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _is_water(cell + offset):
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

# RockSlide.png was drawn on the HU2 highway: drop the light road pixels
# around the rocks so it stands on any ground.
static var _rock_texture: Texture2D

static func _clean_rock_texture() -> Texture2D:
	if _rock_texture != null:
		return _rock_texture
	var image := ROCK_TEXTURE.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0 and c.b > c.r + 0.05 and c.b > 0.55:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	_rock_texture = ImageTexture.create_from_image(image)
	return _rock_texture

func _rock(foot: Vector2, scale_value: float) -> void:
	var rock := Sprite2D.new()
	rock.texture = _clean_rock_texture()
	rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rock.scale = Vector2(scale_value, scale_value)
	rock.position = foot - Vector2(0, ROCK_TEXTURE.get_height() * scale_value * 0.5 - 6)
	_decor.add_child(rock)
	WorldDepth.place(rock, foot.y)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(120, 26)
	shape.shape = box
	body.position = Vector2(0, ROCK_TEXTURE.get_height() * 0.5 - 18)
	body.add_child(shape)
	rock.add_child(body)
