extends SceneTree

# Screenshots of the open world (must run WITH a window):
#   Godot --path . --script res://tools/capture_open_world.gd -- --out=<dir>
# overview.png (whole Earth), island_edge.png, city_coast.png,
# city_wastes.png, sea.png

var out_dir := "user://open_world_captures"
var player: Player

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	(game.get_node("SaveManager") as SaveManager).save_path = "res://audit-open-world-capture-save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	for node in get_nodes_in_group("enemy"):
		node.set_physics_process(false)
	var ui := game.get_node("UIContainer") as CanvasLayer
	ui.visible = false

	await _shot(Vector2(6440, 3060), "island_edge.png")
	await _shot(Vector2(5200, 3000), "sea.png")
	await _shot(Vector2(1640, 2600), "city_west.png")
	await _shot(Vector2(2944, 2500), "city_wastes.png")
	await _shot(Vector2(3100, 1160), "mountains.png")
	await _shot(Vector2(4300, 1600), "forest.png")
	await _shot(Vector2(4000, 3000), "wastes_south.png")
	await _shot(Vector2(3200, 600), "snow.png")
	await _shot(Vector2(4710, 2000), "river.png")
	# Shores: a cliff (land north of the water) and a grass shore.
	var earth := get_first_node_in_group("open_world") as OpenWorld
	if earth == null:
		earth = game.get_node("WorldContainer").get_child(0) as OpenWorld
	var cliffs := 0
	for y in range(20, 130, 3):
		for x in range(10, 200, 3):
			if cliffs < 3 and earth.terrain.is_cliff_cell(Vector2i(x, y)) and earth.terrain.is_cliff_cell(Vector2i(x + 3, y)):
				await _shot(Vector2(x * 32, y * 32), "cliff_%d.png" % cliffs)
				cliffs += 1
				break

	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.zoom = Vector2(0.0585, 0.0585)
	player.global_position = Vector2(3328, 2304)
	await _save("overview.png")
	# The sky above the planet.
	camera.zoom = Vector2.ONE
	var world := get_first_node_in_group("world_manager") as WorldManager
	player.global_position = Vector2(2300, 2000)
	player.set_physics_process(true)
	player.toggle_flight()
	await create_timer(0.6).timeout
	await world.ascend_to_sky()
	await create_timer(0.3).timeout
	player.set_physics_process(false)
	ui.visible = true
	await _shot(SkyWorld.to_sky(Vector2(2300, 2000)), "sky_west_city.png")
	await _shot(SkyWorld.to_sky(Vector2(5900, 3000)), "sky_kame.png")
	await _shot(SkyWorld.to_sky(Vector2(3300, 900)), "sky_mountains.png")
	ui.visible = false
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.zoom = Vector2(0.37, 0.37)
	player.global_position = Vector2(624, 432)
	await _save("sky_overview.png")
	(game.get_node("SaveManager") as SaveManager).delete_save()
	print("OPEN WORLD CAPTURES ", out_dir)
	quit(0)

func _shot(at: Vector2, file: String) -> void:
	player.global_position = at
	await create_timer(0.2).timeout
	await _save(file)

func _save(file: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file))
