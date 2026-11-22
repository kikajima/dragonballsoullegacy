extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func effective_z(item: Node2D) -> int:
	var value := item.z_index
	if item.z_as_relative and item.get_parent() is Node2D:
		value += effective_z(item.get_parent())
	return value

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node
	game.get_node("GameSession").autosave_on_quest_complete = false
	game.get_node("SaveManager").save_path = "res://audit-depth-save.json"
	root.add_child(game)
	current_scene = game
	await create_timer(0.2).timeout
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	game.get_node("PlayerDashSystem").set_process(false)
	var manager := game.get_node("WorldManager") as WorldManager
	var depth := game.get_node("WorldAmbientFX") as WorldAmbientFX
	var cases := {
		"kame_island": [["KameHouse/CollisionShape2D", "KameHouse/Sprite2D"], ["PalmTreeLeft/Footprint/CollisionShape2D", "PalmTreeLeft"]],
		"kame_house_interior": [["Table/CollisionShape2D", "Table/LibraryArt"], ["Bed/CollisionShape2D", "Bed/LibraryArt"]],
		"west_city_outskirts": [["CapsuleBuilding/CollisionShape2D", "CapsuleBuilding/LibraryArt"], ["CityAnnex/Footprint/@CollisionShape2D@", "CityAnnex/LibraryArt"]],
		"rocky_wastes": [["RockA/CollisionShape2D", "RockA/LibraryArt"]],
		"capsule_training_chamber": [["CenterPlatform/CollisionShape2D", "CenterPlatform/LibraryArt"], ["GravityConsole/Footprint/CollisionShape2D", "GravityConsole/LibraryArt"]],
	}
	for map in cases:
		manager.load_world("res://scenes/world/" + map + ".tscn")
		var world := manager.world_container.get_child(0)
		for enemy in get_nodes_in_group("enemy"):
			enemy.set_physics_process(false)
		await physics_frame
		await physics_frame
		for entry in cases[map]:
			var collision: CollisionShape2D
			if String(entry[0]).contains("@CollisionShape2D@"):
				collision = world.get_node("CityAnnex/Footprint").get_child(0)
			else:
				collision = world.get_node(entry[0])
			var art := world.get_node(entry[1]) as Node2D
			var bounds: Rect2 = collision.global_transform * collision.shape.get_rect()
			player.global_position = Vector2(bounds.get_center().x, bounds.end.y + 32)
			var hit := player.move_and_collide(Vector2(0, -64))
			check(hit != null, "Missing south contact: " + str(entry))
			depth._update_depth_sorting()
			check(effective_z(player) > effective_z(art), "Goku torso hidden south of " + str(entry[1]))
			if DisplayServer.get_name() != "headless":
				await create_timer(0.1).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://audit-depth-" + map + "-" + String(art.get_parent().name) + ".png")
			player.global_position = Vector2(bounds.get_center().x, bounds.position.y - 32)
			player.move_and_collide(Vector2(0, 64))
			depth._update_depth_sorting()
			check(effective_z(player) < effective_z(art), "Goku must remain behind the north side of " + str(entry[1]))
		print("Depth ordering: ", map)
	game.get_node("SaveManager").delete_save()
	print("Scenery depth: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
