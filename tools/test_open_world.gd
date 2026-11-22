extends SceneTree

# Open world (Earth): Kame Island, West City and the Rocky Wastes in one map.
#   Godot --headless --path . --script res://tools/test_open_world.gd

var failures := 0
var game: Node
var player: Player
var world: WorldManager
var earth: OpenWorld

func _expect(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, "  ", detail)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-open-world-save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.4).timeout
	player = get_first_node_in_group("player") as Player
	world = get_first_node_in_group("world_manager") as WorldManager
	earth = world.world_container.get_child(0) as OpenWorld
	var transition := get_first_node_in_group("screen_transition") as ScreenTransition
	if transition != null:
		transition.default_duration = 0.02

	await _case_layout()
	await _case_walk_between_regions()
	await _case_sea()
	await _case_ferry()
	await _case_interiors()
	await _case_terrain()
	await _case_depth()
	await _case_sky()
	_case_old_save()
	saves.delete_save()
	print("Open world: ", failures, " failures")
	quit(1 if failures > 0 else 0)

func _region(name: String) -> Node2D:
	return earth.get_node(name) as Node2D

func _case_layout() -> void:
	_expect("one world: Earth is loaded", earth != null and world.current_world_path == OpenWorld.SCENE_PATH, world.current_world_path)
	_expect("three regions", earth.get_regions().size() == 3, str(earth.get_regions().size()))
	var bounds := get_nodes_in_group("world_bounds")
	_expect("only the world's bounds drive camera and flight", bounds.size() == 1 and bounds[0].get_parent() == earth, str(bounds.size()))
	var camera := player.get_node("Camera2D") as Camera2D
	await process_frame
	_expect("camera covers the whole world", camera.limit_right == 6656 and camera.limit_bottom == 4608, "%d %d" % [camera.limit_right, camera.limit_bottom])
	_expect("the game starts on Kame Island", earth.region_at(player.global_position) == _region("KameIsland"), str(player.global_position))
	_expect("the island keeps its own coast and sea", _region("KameIsland").has_node("Terrain/LandSilhouette"))
	_expect("city scenery is built", _region("WestCityOutskirts").has_node("CityAnnex"))
	_expect("wastes scenery is built", _region("RockyWastes").has_node("LibraryRubble"))
	var fx := game.get_node("WorldAmbientFX") as WorldAmbientFX
	_expect("ambient effects for every region", fx._item_modes.has(WorldAmbientFX.MODE_KAME) and fx._item_modes.has(WorldAmbientFX.MODE_CITY) and fx._item_modes.has(WorldAmbientFX.MODE_WASTES), str(fx._item_modes.size()))
	_expect("no region-to-region portals left", _region("WestCityOutskirts").get_node_or_null("RockyWastesRoute") == null and _region("RockyWastes").get_node_or_null("ReturnToWestCity") == null)
	_expect("regions are placed where the layout says", _layout_matches(), "")
	_expect("the planet has terrain", earth.terrain != null and earth.terrain.get_used_cells().size() > 20000, str(earth.terrain.get_used_cells().size() if earth.terrain else 0))

func _layout_matches() -> bool:
	for name in OpenWorld.DATA.REGIONS:
		var tile: Vector2 = OpenWorld.DATA.REGIONS[name][0]
		if _region(name).position != tile * 32.0:
			return false
	return true

func _walk(direction: StringName, seconds: float) -> void:
	Input.action_press(direction)
	await create_timer(seconds).timeout
	Input.action_release(direction)
	await physics_frame

func _case_walk_between_regions() -> void:
	var city := _region("WestCityOutskirts")
	var wastes := _region("RockyWastes")
	# Along the main road, towards the wastes.
	player.global_position = city.to_global(Vector2(1220, 400))
	await physics_frame
	await _walk(&"move_right", 1.6)
	_expect("walking east leaves West City into the Rocky Wastes", earth.region_at(player.global_position) == wastes, str(player.global_position))
	await _walk(&"move_left", 1.6)
	_expect("and walking back returns to West City", earth.region_at(player.global_position) == city, str(player.global_position))
	# Walking west out of the city reaches the beach, never the sea.
	player.global_position = city.to_global(Vector2(60, 300))
	await physics_frame
	await _walk(&"move_left", 4.0)
	_expect("west of West City there is open land", player.global_position.x < city.global_position.x - 64.0, str(player.global_position))
	_expect("the coast stops you from walking into the sea", earth.terrain.is_walkable(player.global_position), str(player.global_position))

func _case_sea() -> void:
	var island := _region("KameIsland")
	_expect("open sea: no landing", not earth.is_landable_point(Vector2(6000, 1200)))
	_expect("island sea: no landing", not earth.is_landable_point(island.to_global(Vector2(40, 40))))
	_expect("island ground: landing", earth.is_landable_point(island.to_global(Vector2(480, 420))))
	_expect("city ground: landing", earth.is_landable_point(_region("WestCityOutskirts").to_global(Vector2(600, 400))))
	# Fly from the island to the mainland over the sea.
	player.global_position = island.to_global(Vector2(600, 420))
	await physics_frame
	player.toggle_flight()
	await create_timer(0.5).timeout
	_expect("taking off on the island", player.is_flying())
	player.global_position = Vector2(6000, 1200)
	await physics_frame
	player.toggle_flight()
	await create_timer(0.8).timeout
	_expect("flying over the sea is allowed", Rect2(Vector2.ZERO, OpenWorld.world_size()).has_point(player.global_position))
	_expect("you never land in the sea", not player.is_flying() and earth.is_landable_point(player.global_position) or player.is_flying(), "%s flying=%s" % [player.global_position, player.is_flying()])
	player.flight_component.land_immediately()

func _case_ferry() -> void:
	var island := _region("KameIsland")
	var boat := island.get_node("WestCityBoat") as WorldPortal
	var instance_id := earth.get_instance_id()
	boat.interact(player)
	await create_timer(0.5).timeout
	_expect("the island capsule ship takes you to West City", earth.region_at(player.global_position) == _region("WestCityOutskirts"), str(player.global_position))
	_expect("without reloading the world", is_instance_valid(earth) and earth.get_instance_id() == instance_id and world.current_world_path == OpenWorld.SCENE_PATH)
	var route := _region("WestCityOutskirts").get_node("KameIslandRoute") as WorldPortal
	route.interact(player)
	await create_timer(0.5).timeout
	_expect("and the city capsule ship takes you back", earth.region_at(player.global_position) == island, str(player.global_position))
	_expect("the city has its capsule ship", _region("WestCityOutskirts").has_node("TravelCapsule"))

func _case_interiors() -> void:
	var entrance := _region("KameIsland").get_node("KameHouseEntrance") as WorldPortal
	entrance.interact(player)
	await create_timer(0.5).timeout
	_expect("Kame House is still its own room", world.current_world_path == "res://scenes/world/kame_house_interior.tscn", world.current_world_path)
	var exit := world.world_container.get_child(0).get_node("Exit") as WorldPortal
	exit.interact(player)
	await create_timer(0.5).timeout
	earth = world.world_container.get_child(0) as OpenWorld
	_expect("leaving the house returns to Earth", earth != null and world.current_world_path == OpenWorld.SCENE_PATH)
	_expect("in front of Kame House", earth != null and earth.region_at(player.global_position) == _region("KameIsland") and player.global_position.distance_to(Vector2(5986, 3126)) < 2.0, str(player.global_position))
	world.load_world("res://scenes/world/capsule_training_chamber.tscn", Vector2(90, 430), true)
	await process_frame
	var chamber_exit := world.world_container.get_child(0).get_node("Exit") as WorldPortal
	chamber_exit.interact(player)
	await create_timer(0.5).timeout
	earth = world.world_container.get_child(0) as OpenWorld
	_expect("leaving the training chamber returns to Capsule Corp", earth != null and earth.region_at(player.global_position) == _region("WestCityOutskirts"), str(player.global_position))

func _case_old_save() -> void:
	var data := {
		"world": {"current_world_path": "res://scenes/world/west_city_outskirts.tscn"},
		"player": {"position": {"x": 240.0, "y": 185.0}},
		"checkpoint": {"world_path": "res://scenes/world/rocky_wastes.tscn", "position_x": 160.0, "position_y": 585.0},
	}
	SaveManager.upgrade_to_open_world(data)
	_expect("old save: map becomes Earth", data["world"]["current_world_path"] == OpenWorld.SCENE_PATH)
	_expect("old save: player moved into West City", Vector2(data["player"]["position"]["x"], data["player"]["position"]["y"]) == Vector2(1904, 2297), str(data["player"]["position"]))
	_expect("old save: checkpoint moved into the wastes", data["checkpoint"]["world_path"] == OpenWorld.SCENE_PATH and Vector2(data["checkpoint"]["position_x"], data["checkpoint"]["position_y"]) == Vector2(3104, 2697), str(data["checkpoint"]))
	var interior := {"world": {"current_world_path": "res://scenes/world/kame_house_interior.tscn"}, "player": {"position": {"x": 272.0, "y": 305.0}}}
	SaveManager.upgrade_to_open_world(interior)
	_expect("old save: interiors are left alone", interior["world"]["current_world_path"] == "res://scenes/world/kame_house_interior.tscn" and interior["player"]["position"]["x"] == 272.0)
	var v6 := {
		"world": {"current_world_path": OpenWorld.SCENE_PATH},
		"player": {"position": {"x": 2000.0, "y": 485.0}},
		"checkpoint": {"world_path": OpenWorld.SCENE_PATH, "position_x": 3200.0, "position_y": 885.0},
	}
	SaveManager.upgrade_open_world_layout(v6)
	_expect("first open world save: player keeps its spot in West City", Vector2(v6["player"]["position"]["x"], v6["player"]["position"]["y"]) == Vector2(1904, 2297), str(v6["player"]["position"]))
	_expect("first open world save: checkpoint keeps its spot", Vector2(v6["checkpoint"]["position_x"], v6["checkpoint"]["position_y"]) == Vector2(3104, 2697), str(v6["checkpoint"]))

func _tile_center(tile: Vector2) -> Vector2:
	return tile * 32.0 + Vector2(16, 16)

func _find_tile(biome: int) -> Vector2:
	var terrain := earth.terrain
	for y in range(8, 136):
		for x in range(8, 200):
			if terrain.biome_at_cell(Vector2i(x, y)) == biome and earth.region_at(_tile_center(Vector2(x, y))) == null:
				return Vector2(x, y)
	return Vector2(-1, -1)

func _case_terrain() -> void:
	var terrain := earth.terrain
	for biome in [EarthTerrain.Biome.DEEP, EarthTerrain.Biome.SHALLOW, EarthTerrain.Biome.SAND, EarthTerrain.Biome.GRASS,
			EarthTerrain.Biome.FOREST, EarthTerrain.Biome.DIRT, EarthTerrain.Biome.MOUNTAIN, EarthTerrain.Biome.SNOW,
			EarthTerrain.Biome.RIVER, EarthTerrain.Biome.PATH, EarthTerrain.Biome.BRIDGE]:
		_expect("terrain has %s" % EarthTerrain.Biome.keys()[biome], _find_tile(biome).x >= 0)
	var mountain := _tile_center(_find_tile(EarthTerrain.Biome.MOUNTAIN))
	_expect("mountains: no walking, no landing", not terrain.is_walkable(mountain) and not earth.is_landable_point(mountain))
	_expect("bridges cross rivers on foot", terrain.is_walkable(_tile_center(_find_tile(EarthTerrain.Biome.BRIDGE))))
	_expect("zones: the northern range", earth.zone_at(_tile_center(Vector2(100, 28))) == "NORTHERN MOUNTAINS", earth.zone_at(_tile_center(Vector2(100, 28))))
	_expect("zones: the holy land", earth.zone_at(_tile_center(Vector2(20, 70))) == "HOLY LAND FOREST", earth.zone_at(_tile_center(Vector2(20, 70))))
	# Walk north from the plains into the mountain wall: it stops you.
	player.global_position = _tile_center(Vector2(100, 46))
	await physics_frame
	await _walk(&"move_up", 4.0)
	_expect("the mountain wall stops walkers", player.global_position.y > _tile_center(Vector2(100, 37)).y, str(player.global_position))

func _case_depth() -> void:
	player.global_position = _tile_center(Vector2(100, 120))
	await process_frame
	await process_frame
	_expect("depth origin follows the player far south", WorldDepth.origin_y > 0.0, str(WorldDepth.origin_y))
	_expect("actors stay inside Godot's z range", player.z_index > 0 and player.z_index < 4096, str(player.z_index))
	var tree: Node2D = null
	for item in earth.terrain.get_decor().get_children():
		if absf((item as Node2D).global_position.y - player.global_position.y) < 200.0:
			tree = item
			break
	if tree != null:
		_expect("nearby scenery is sorted with the player", absi(tree.z_index - player.z_index) < 400, "%d vs %d" % [tree.z_index, player.z_index])

func _case_sky() -> void:
	var start := _tile_center(Vector2(71, 53))
	player.global_position = start
	player.flight_component.land_immediately()
	await physics_frame
	player.travel_sky()
	await create_timer(0.3).timeout
	_expect("sky: you must be flying to go up", world.current_world_path == OpenWorld.SCENE_PATH)
	player.toggle_flight()
	await create_timer(0.5).timeout
	await _tap(&"sky_travel")
	await create_timer(0.6).timeout
	_expect("sky: U while flying goes up", world.is_in_sky(), world.current_world_path)
	var sky := world.world_container.get_child(0) as SkyWorld
	_expect("sky: the planet map", sky != null and sky.map_sprite.texture.get_size() == Vector2(OpenWorld.DATA.SIZE * OpenWorld.DATA.SKY_TILE))
	_expect("sky: right above where you were", player.global_position.distance_to(SkyWorld.to_sky(start)) < 3.0, "%s vs %s" % [player.global_position, SkyWorld.to_sky(start)])
	_expect("sky: still flying", player.is_flying())
	_expect("sky: knows what is below", sky != null and sky.place_below(player.global_position) == "Ginger Town", sky.place_below(player.global_position) if sky != null else "")
	var before := player.global_position
	await _walk(&"move_right", 1.0)
	_expect("sky: flying moves across the planet", player.global_position.x > before.x + 40.0, str(player.global_position))
	await _tap(&"attack")
	_expect("sky: no fighting up here", not player.melee_combat_component.is_attacking())
	# Fly to the Rocky Wastes and come down there.
	player.global_position = SkyWorld.to_sky(OpenWorld.from_legacy("res://scenes/world/rocky_wastes.tscn", Vector2(640, 300)))
	await physics_frame
	await _tap(&"toggle_flight")
	await create_timer(1.6).timeout
	earth = world.world_container.get_child(0) as OpenWorld
	_expect("sky: V comes back down to Earth", earth != null and world.current_world_path == OpenWorld.SCENE_PATH, world.current_world_path)
	_expect("sky: landing right below, in the Rocky Wastes", earth != null and earth.region_at(player.global_position) == earth.get_node("RockyWastes"), str(player.global_position))
	_expect("sky: and on the ground", not player.is_flying(), "")
	# Over the open sea: you come down at the nearest shore or stay up.
	player.toggle_flight()
	await create_timer(0.5).timeout
	player.travel_sky()
	await create_timer(0.6).timeout
	player.global_position = SkyWorld.to_sky(Vector2(6000, 1200))
	await physics_frame
	player.travel_sky()
	await create_timer(1.4).timeout
	earth = world.world_container.get_child(0) as OpenWorld
	_expect("sky: coming down over the sea never lands in the water", earth != null and (player.is_flying() or earth.is_landable_point(player.global_position)), "%s flying=%s" % [player.global_position, player.is_flying()])
	player.flight_component.land_immediately()

func _tap(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frame
	await physics_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
