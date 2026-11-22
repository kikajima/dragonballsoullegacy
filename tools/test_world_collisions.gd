extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

# Sweep the real actor body, including its foot offset, from outside a known
# ground footprint. A mask-only assertion would miss displaced/disabled shapes.
func check_sides(actor: CharacterBody2D, obstacle: Node2D, bounds: Rect2) -> void:
	var foot_offset := (actor.get_node("CollisionShape2D") as CollisionShape2D).position
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var extent := bounds.size.x * 0.5 if direction.x != 0 else bounds.size.y * 0.5
		actor.global_position = bounds.get_center() + direction * (extent + 20.0) - foot_offset
		var hit := actor.move_and_collide(-direction * (extent + 20.0))
		check(hit != null and hit.get_collider() == obstacle,
			"%s must block %s approaching from %s" % [obstacle.name, actor.name, direction])
		var foot := actor.global_position + foot_offset
		check(not bounds.grow(-0.1).has_point(foot), "Actor entered " + String(obstacle.name))

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.2).timeout
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	game.get_node("PlayerDashSystem").set_process(false)
	var manager := game.get_node("WorldManager") as WorldManager
	var enemy_scene := load("res://actors/enemies/debug_goku_enemy.tscn") as PackedScene
	var mob := enemy_scene.instantiate() as DebugGokuEnemy
	game.add_child(mob)
	mob.set_physics_process(false)
	var other := enemy_scene.instantiate() as DebugGokuEnemy
	game.add_child(other)
	other.set_physics_process(false)
	other.position = Vector2(-500, -500)
	mob.position = Vector2(-700, -500)
	await physics_frame
	await physics_frame
	check_sides(player, other, Rect2(-505, -496, 10, 8))
	player.position = Vector2(-900, -500)
	check_sides(mob, other, Rect2(-505, -496, 10, 8))
	# Respawning on the player must choose a free location, even when the
	# preferred separation direction is a wall and another mob is nearby.
	var wall := StaticBody2D.new()
	wall.position = Vector2(-524, -492)
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(20, 60)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	game.add_child(wall)
	player.position = Vector2(-500, -500)
	player.facing_component.update_from_direction(Vector2.RIGHT)
	other.position = Vector2(-476, -500)
	mob._spawn_position = player.position
	mob._reset_after_defeat()
	await physics_frame
	await physics_frame
	mob._process_respawn_collision(1.0)
	check(not mob._respawn_collision_pending, "Respawn must find a nearby free position")
	check(mob._respawn_position_is_clear(mob.global_position), "Respawn overlaps a wall or actor")
	check(mob.global_position.distance_to(player.global_position) >= 12.0, "Respawn overlaps player")
	wall.queue_free()
	other.queue_free()
	mob.position = Vector2(-700, -500)
	player.position = Vector2(-900, -500)
	await physics_frame
	check_sides(mob, player, Rect2(-905, -496, 10, 8))

	for map in ["kame_island", "west_city_outskirts", "kame_house_interior"]:
		manager.load_world("res://scenes/world/" + map + ".tscn")
		var world := manager.world_container.get_child(0)
		for enemy in get_nodes_in_group("enemy"):
			enemy.set_physics_process(false)
		await physics_frame
		await physics_frame
		var cases: Array = []
		match map:
			"kame_island":
				# Measured wall footprint of NewKameHouse.png after scene scaling.
				cases = [[world.get_node("KameHouse"), Rect2(434.08, 205.6, 103.32, 123.0)]]
			"west_city_outskirts":
				cases = [[world.get_node("CapsuleBuilding"), Rect2(798, 184, 224, 96)],
					[world.get_node("CityAnnex/Footprint"), Rect2(310, 120, 160, 60)]]
			"kame_house_interior":
				for path in ["Fridge/Footprint", "TV/Footprint"]:
					var body := world.get_node_or_null(path) as StaticBody2D
					check(body != null, path + " needs a physical body, not just an interaction area")
					if body != null:
						var shape := body.get_child(0) as CollisionShape2D
						var size := (shape.shape as RectangleShape2D).size
						cases.append([body, Rect2(shape.global_position - size * 0.5, size)])
		for test_case in cases:
			mob.position = Vector2(-700, -500)
			check_sides(player, test_case[0], test_case[1])
			player.position = Vector2(-900, -500)
			check_sides(mob, test_case[0], test_case[1])
		# The house/training entrance must still be reachable outside the wall.
		var entrance := world.get_node_or_null("KameHouseEntrance") as Node2D
		if map == "west_city_outskirts":
			entrance = world.get_node("CapsuleTrainingEntrance") as Node2D
		if entrance != null:
			player.global_position = entrance.global_position + Vector2(0, 24)
			check(player.move_and_collide(Vector2(0, -24)) == null, "Door approach blocked in " + map)
	print("World collisions: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
