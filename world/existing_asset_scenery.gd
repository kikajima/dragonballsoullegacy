extends RefCounted

# Reviewed HU2 art. Source textures stay at native pixel size; actor depth uses
# the same foot-based ordering as WorldAmbientFX. Interaction nodes stay intact.
const IMAGES := "res://assets/vendor/hu2/Icons/Images/"
const TURFS := "res://assets/vendor/hu2/Icons/Turfs/"
const FURNITURE := "res://assets/sprites/environment/gba_furniture/"

static func apply(world: Node2D) -> void:
	if world.has_meta("library_scenery_applied"):
		return
	world.set_meta("library_scenery_applied", true)
	match String(world.name):
		"KameHouseInterior":
			_house(world)
		"WestCityOutskirts":
			_city(world)
		"RockyWastes":
			_wastes(world)
		"CapsuleTrainingChamber":
			_training(world)
		"KameIsland":
			if _gba_prop(world, "BeachChair", "beach_chair", 14, ["Seat", "Legs", "SeatStripe"]):
				(world.get_node("BeachChair") as Node2D).rotation = 0.0
	_mark_checkpoints(world)

static func _mark_checkpoints(world: Node2D) -> void:
	# A floor marker from the HU2 tileset replaces the translucent placeholder.
	for node in world.get_children():
		if not node is CheckpointArea:
			continue
		var marker := Node2D.new()
		marker.name = "CheckpointArt"
		marker.z_as_relative = false
		marker.z_index = 2
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.add_child(marker)
		for item in [["PortalTL", Vector2(-32, -32)], ["PortalTR", Vector2(0, -32)], ["PortalBL", Vector2(-32, 0)], ["PortalBR", Vector2(0, 0)]]:
			_tile(marker, "CityTurfs", item[0], item[1])
		_hide(node, ["Visual"])

static func _decoration(world: Node2D, node_name: String, asset: String, at: Vector2, foot: float, footprint: Vector2 = Vector2.ZERO) -> Node2D:
	if not ResourceLoader.exists(FURNITURE + asset + ".png"):
		return null
	var prop := Node2D.new()
	prop.name = node_name
	prop.position = at
	world.add_child(prop)
	if _gba_prop(world, String(prop.name), asset, foot, []) and not footprint.is_zero_approx():
		_footprint(prop, footprint, Vector2(0, foot - footprint.y * 0.5))
	return prop

static func _gba_prop(world: Node2D, path: String, asset: String, foot: float, old: Array[String]) -> bool:
	var texture_path := FURNITURE + asset + ".png"
	if not ResourceLoader.exists(texture_path):
		return false
	var owner := world.get_node_or_null(path) as Node2D
	if owner == null:
		return false
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false
	var art := _art_root(owner, foot)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = Vector2(0, foot - texture.get_height() * 0.5)
	sprite.set_meta("asset_source", texture_path)
	art.add_child(sprite)
	_hide(owner, old)
	return true

static func _house(world: Node2D) -> void:
	if _gba_prop(world, "Bed", "bed", 24, ["Mattress", "Pillow"]):
		# Original block was a horizontal bed. The reviewed sprite faces south.
		for path in ["Bed/CollisionShape2D", "Bed/RestInteraction/CollisionShape2D"]:
			var shape := RectangleShape2D.new()
			shape.size = Vector2(40, 48)
			(world.get_node(path) as CollisionShape2D).shape = shape
	if _gba_prop(world, "Table", "table", 21, ["Visual"]):
		var shape := RectangleShape2D.new()
		shape.size = Vector2(48, 40)
		(world.get_node("Table/CollisionShape2D") as CollisionShape2D).shape = shape
	_gba_prop(world, "TV", "tv", 17, ["Screen", "Glow"])
	_gba_prop(world, "Fridge", "fridge", 30, ["Body", "Handle"])
	if _gba_prop(world, "Sofa", "sofa", 24, ["Back", "Seat", "LeftArm", "RightArm"]):
		_footprint(world.get_node("Sofa"), Vector2(30, 44), Vector2(0, 2))
	if _gba_prop(world, "CoffeeTable", "coffee_table", 14, ["Visual"]):
		_footprint(world.get_node("CoffeeTable"), Vector2(46, 24), Vector2(0, 1))
	var shelf := _decoration(world, "HouseShelf", "shelf", Vector2(190, 86), 16, Vector2(46, 14))
	if shelf != null:
		_gba_prop(world, "HouseShelf", "bookshelf", 16, [])
	_decoration(world, "HousePlant", "house_plant", Vector2(462, 270), 12, Vector2(18, 10))
	var rug := _decoration(world, "HouseRug", "rug", Vector2(282, 194), 24)
	if rug != null:
		(rug.get_node("LibraryArt") as Node2D).z_index = -6

static func _art_root(parent: Node2D, foot_y: float) -> Node2D:
	var art := Node2D.new()
	art.name = "LibraryArt"
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.z_as_relative = false
	art.z_index = 1000 + roundi(parent.global_position.y + foot_y)
	parent.add_child(art)
	return art

static func _tile(parent: Node2D, sheet: String, state: String, at: Vector2) -> Sprite2D:
	var path := TURFS + sheet + ".dmi"
	var dmi := DmiSpriteSheet.load_file(path)
	if dmi == null or not dmi.has_state(StringName(state)):
		push_error("Scenery tile missing: " + path + " / " + state)
		return null
	var sprite := Sprite2D.new()
	sprite.texture = dmi.get_frame_texture(StringName(state), &"down", 0)
	sprite.position = at
	sprite.centered = false
	sprite.set_meta("asset_source", path + ":" + state)
	parent.add_child(sprite)
	return sprite

static func _image(parent: Node2D, file: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(IMAGES + file) as Texture2D
	sprite.position = at
	sprite.set_meta("asset_source", IMAGES + file)
	parent.add_child(sprite)
	return sprite

static func _hide(parent: Node, paths: Array[String]) -> void:
	for path in paths:
		var old := parent.get_node_or_null(path) as CanvasItem
		if old != null:
			old.hide()

static func _city(world: Node2D) -> void:
	_city_annex(world)
	_decoration(world, "WestCitySign", "west_city_sign", Vector2(165, 230), 16, Vector2(28, 8))
	var building := world.get_node("CapsuleBuilding") as Node2D
	var facade := _art_root(building, 70)
	# Seven columns, two roof rows and three facade rows. Door center remains
	# aligned with the training portal immediately south of the building.
	for row in range(5):
		for column in range(7):
			var state := "MM1"
			if row == 0:
				state = "RoofTL" if column == 0 else ("RoofTR" if column == 6 else "RoofTM")
			elif row == 1:
				state = "RoofBL" if column == 0 else ("RoofBR" if column == 6 else "RoofBM")
			elif row == 2:
				state = "TL" if column == 0 else ("TR" if column == 6 else "TM")
			elif row == 3:
				state = "ML" if column == 0 else ("MR" if column == 6 else "MM1")
			else:
				state = "BL" if column == 0 else ("BR" if column == 6 else ("Door" if column == 3 else "BM"))
			_tile(facade, "RectBuilding", state, Vector2(-112 + column * 32, -90 + row * 32))
	_hide(building, ["Visual", "Roof"])
	var park := world.get_node("CityPark") as Node2D
	var planting := _art_root(park, 35)
	for column in range(5):
		_tile(planting, "CityTurfs", "PlantL" if column == 0 else ("PlantR" if column == 4 else "PlantM"), Vector2(-80 + column * 32, 3))
	_image(planting, "FancyTree.png", Vector2(0, -27))
	# Benches are placed on the pavement, outside spawn/portal corridors.
	for at in [Vector2(260, 290), Vector2(510, 290)]:
		var bench := Node2D.new()
		bench.name = "LibraryBench"
		bench.position = at
		world.add_child(bench)
		var art := _art_root(bench, 12)
		_tile(art, "CityTurfs", "BenchL", Vector2(-32, -20))
		_tile(art, "CityTurfs", "BenchR", Vector2(0, -20))
		_footprint(bench, Vector2(60, 12), Vector2(0, 6))
	var markings := Node2D.new()
	markings.name = "LibraryRoadMarkings"
	markings.z_index = 1
	world.add_child(markings)
	for x in [624, 656, 816, 848]:
		for y in [356, 388, 420]:
			_tile(markings, "CityTurfs", "CrossWalkV", Vector2(x, y))

static func _city_annex(world: Node2D) -> void:
	var building := Node2D.new()
	building.name = "CityAnnex"
	building.position = Vector2(390, 150)
	world.add_child(building)
	var art := _art_root(building, 30)
	var rows := [
		["TL", "TM", "TM", "TM", "TR"],
		["TML", "TMM", "TMM", "TMM", "TMR"],
		["ML", "MMWindow", "MM", "MMWindow", "MR"],
		["BL", "Window", "Door", "Window", "BR"],
	]
	for row in range(rows.size()):
		for column in range(5):
			_tile(art, "SquareBuilding", rows[row][column], Vector2(-80 + column * 32, -98 + row * 32))
	_footprint(building, Vector2(160, 60), Vector2.ZERO)

static func _footprint(parent: Node2D, extent: Vector2, at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = extent
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func _wastes(world: Node2D) -> void:
	var ground_path := FURNITURE + "wastes_ground.png"
	if ResourceLoader.exists(ground_path):
		var ground := world.get_node("Ground") as Polygon2D
		ground.texture = load(ground_path) as Texture2D
		ground.uv = ground.polygon
		ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.color = Color.WHITE
	for name in ["RockA", "RockC"]:
		var rock := world.get_node(name) as Node2D
		var foot := 40 if name == "RockA" else 28
		var art := _art_root(rock, foot)
		var sprite := _image(art, "RockSlide.png", Vector2(0, foot - 48))
		var land_material := ShaderMaterial.new()
		land_material.shader = preload("res://assets/shaders/rock_slide_land.gdshader")
		sprite.material = land_material
		_hide(rock, ["Visual"])
	# Low rubble is ground detail, not a new navigation obstacle.
	var rubble := Node2D.new()
	rubble.name = "LibraryRubble"
	rubble.z_index = 1
	world.add_child(rubble)
	for at in [Vector2(255, 275), Vector2(565, 300), Vector2(660, 510), Vector2(910, 430), Vector2(1080, 610)]:
		_tile(rubble, "Flowers", "rock6", at)
		_tile(rubble, "Flowers", "rock8", at + Vector2(24, 16))

static func _training(world: Node2D) -> void:
	var walls := Node2D.new()
	walls.name = "LibraryChamberWalls"
	walls.z_index = 1
	world.add_child(walls)
	for column in range(25):
		_tile(walls, "ApartmentInts", "BaseWall", Vector2(10 + column * 32, 0))
	var platform := world.get_node("CenterPlatform") as Node2D
	var machine := _art_root(platform, 35)
	_image(machine, "GravMachine.png", Vector2(0, -29))
	_gba_prop(world, "GravityConsole", "terminal", 12, ["Visual", "Screen"])
	_gba_prop(world, "SparringConsole", "terminal", 13, ["Visual", "Screen"])
	_gba_prop(world, "RecoveryStation", "recovery_pod", 28, ["Pod", "Frame"])
	# The existing DMI punching-bag artwork was covered by primitive extras.
	_hide(world, ["PunchingBag/Visual", "PunchingBag/Stand"])
	var bag := world.get_node("PunchingBag") as Node2D
	bag.z_as_relative = false
	bag.z_index = 1000 + roundi(bag.global_position.y + 12)
