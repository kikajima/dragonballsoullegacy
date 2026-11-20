extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node
	root.add_child(game)
	current_scene = game
	await create_timer(0.2).timeout

	var manager := game.get_node("WorldManager") as WorldManager
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)

	var expected := {
		"kame_house_interior": {"names": ["ChiChi"], "count": 1},
		"kame_island": {"names": ["Krillin"], "count": 3},
		"west_city_outskirts": {"names": ["Bulma"], "count": 1},
		"rocky_wastes": {"names": ["Piccolo"], "count": 1},
		"capsule_training_chamber": {"names": ["Bulma"], "count": 1},
	}

	for map in expected:
		check(
			manager.load_world(
				"res://scenes/world/" + map + ".tscn",
				Vector2(272, 240),
				true
			),
			"NPC test map load failed: " + map
		)
		await process_frame

		var world := game.get_node("WorldContainer").get_child(0) as Node2D
		var npcs: Array[Node] = []
		for candidate in get_nodes_in_group("npc"):
			if world.is_ancestor_of(candidate):
				npcs.append(candidate)
		check(npcs.size() == expected[map]["count"], "Unexpected NPC count: " + map)

		for node_name in expected[map]["names"]:
			var npc := world.get_node_or_null(node_name) as Node2D
			check(npc != null, "Missing NPC " + node_name + " in " + map)
			if npc == null:
				continue

			check(not npc.is_in_group("enemy"), node_name + " must not be an enemy")
			check(npc.get_interaction_label().begins_with("Talk"), "NPC prompt missing")
			check(npc.get_node("BodyCollision").shape != null, "NPC body collision missing")
			check(npc.get_node("InteractionArea").collision_layer == 64, "NPC interaction layer changed")
			check(npc.get_node("Sprite2D").texture != null, "NPC sprite failed to load: " + node_name)

			var dialogue := get_first_node_in_group("dialogue_ui") as DialogueBox
			npc.interact(player)
			check(dialogue.is_open(), "NPC interaction did not open dialogue: " + node_name)
			dialogue.advance()
			dialogue.advance()
			check(dialogue.is_open(), "NPC dialogue closed unexpectedly: " + node_name)
			dialogue.close_dialogue()
			await process_frame

		for portal in world.get_children():
			if not portal is WorldPortal:
				continue
			for npc in npcs:
				check(
					(portal as Node2D).global_position.distance_to(
						(npc as Node2D).global_position
					) >= 36.0,
					"NPC is too close to portal in " + map
				)

	print("World NPCs: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
