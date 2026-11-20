extends SceneTree

const SCENERY = preload("res://world/existing_asset_scenery.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func count_art(node: Node) -> int:
	var count := 0
	if node.has_meta("asset_source"):
		count += 1
		check(node is Sprite2D and node.texture != null, "Missing source texture")
		check(node.scale == Vector2.ONE, "Source pixels must not be stretched")
	for child in node.get_children():
		count += count_art(child)
	return count

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-environment-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	var manager := game.get_node("WorldManager") as WorldManager
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	var views := {
		"kame_house_interior": Vector2(272, 240),
		"capsule_training_chamber": Vector2(400, 200),
		"west_city_outskirts": Vector2(780, 230),
		"rocky_wastes": Vector2(350, 280),
		"kame_island": Vector2(300, 400),
	}
	for map in views:
		check(manager.load_world("res://scenes/world/" + map + ".tscn", views[map], true), "Map load failed: " + map)
		await process_frame
		for enemy in get_nodes_in_group("enemy"):
			enemy.set_physics_process(false)
		await create_timer(0.1).timeout
		var world := game.get_node("WorldContainer").get_child(0) as Node2D
		var total := count_art(world)
		check(total > 0, "Map has no library art: " + map)
		SCENERY.apply(world)
		check(count_art(world) == total, "Repeated setup duplicated props")
		match map:
			"kame_house_interior":
				check(total == 10, "Furniture, shelf, rug and plant must load")
				check(world.get_node("Bed/RestInteraction").has_method("interact"), "Rest interaction lost")
				check(world.get_node("Bed/CollisionShape2D").shape.size == Vector2(40, 48), "Bed collision does not match south-facing sprite")
				check(world.get_node("Sofa/Footprint") is StaticBody2D, "Sofa needs a physical base")
			"west_city_outskirts":
				check(not world.get_node("CapsuleBuilding/Visual").visible, "Old facade remains visible")
				check(world.get_node("CapsuleTrainingEntrance").position == Vector2(910, 310), "Training entrance moved")
				check(world.get_node("CityAnnex/Footprint") is StaticBody2D, "New building needs a collision base")
				var hit := player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(260, 270), Vector2(260, 310), 1))
				check(not hit.is_empty(), "Bench needs a physical base")
			"capsule_training_chamber":
				check(not world.get_node("RecoveryStation/Pod").visible, "Recovery station placeholder remains")
				check(world.get_node("RecoveryStation").has_method("interact"), "Recovery interaction lost")
				check(world.get_node("GravityConsole").has_method("interact"), "Gravity interaction lost")
				check(world.get_node("SparringConsole").has_method("interact"), "Sparring interaction lost")
				var bag := world.get_node("PunchingBag") as TrainingPunchingBag
				bag.receive_hit(1)
				check(bag.visual.dmi_state == &"PunchingBagHit", "Punching bag must use its hit sprites")
				await create_timer(1.0).timeout
				check(bag.visual.dmi_state == &"PunchingBag", "Punching bag must return to idle art")
				(game.get_node("TrainingManager") as TrainingManager).stop_training()
			"kame_island":
				var chair := world.get_node("BeachChair") as Node2D
				for offset in [Vector2(-24, -18), Vector2(24, -18), Vector2(-24, 14), Vector2(24, 14)]:
					check(Geometry2D.is_point_in_polygon(chair.position + offset, world._coast_points()), "Beach chair is floating outside the coast")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://audit-library-" + map + ".png")
			if map in ["west_city_outskirts", "capsule_training_chamber"]:
				player.position = Vector2(280, 220) if map == "west_city_outskirts" else Vector2(620, 390)
				await create_timer(0.1).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://audit-library-detail-" + map + ".png")
		print("Library scenery: ", map, " — ", total, " sprites")
	print("Environment assets: ", "PASS" if failures == 0 else "FAIL")
	saves.delete_save()
	quit(failures)
