extends SceneTree

const MAPS := ["kame_island", "kame_house_interior", "west_city_outskirts", "rocky_wastes", "capsule_training_chamber", "debug_room"]
const REQUIRED := {
	"kame_island": ["KameHouse", "PalmTreeLeft", "PalmTreeRight", "BeachUmbrella", "BeachChair", "BeachGuide", "TravelCapsule", "MasterRoshi", "Turtle", "Krillin"],
	"kame_house_interior": ["Bed", "Table", "TV", "Fridge", "Sofa", "CoffeeTable", "HouseShelf", "HousePlant", "ChiChi"],
	"west_city_outskirts": ["CapsuleBuilding", "CityAnnex", "CityPark", "WestCitySign", "Bulma"],
	"rocky_wastes": ["RockA", "RockB", "RockC", "Piccolo"],
	"capsule_training_chamber": ["CenterPlatform", "GravityConsole", "SparringConsole", "Treadmill", "RecoveryStation", "PunchingBag", "Bulma"],
	"debug_room": ["ObstacleA", "ObstacleB", "MasterRoshiGuide"],
}
var failures := 0
var sweeps := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func bodies_in(node: Node) -> Array[StaticBody2D]:
	var result: Array[StaticBody2D] = []
	if node is StaticBody2D and node.collision_layer & 1:
		for child in node.get_children():
			if (child is CollisionShape2D and child.shape != null and not child.disabled) or (child is CollisionPolygon2D and not child.disabled):
				result.append(node)
				break
	for child in node.get_children():
		result.append_array(bodies_in(child))
	return result

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node
	game.get_node("GameSession").autosave_on_quest_complete = false
	game.get_node("SaveManager").save_path = "res://audit-solid-scenery-save.json"
	root.add_child(game)
	current_scene = game
	await create_timer(0.2).timeout
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	game.get_node("PlayerDashSystem").set_process(false)
	var manager := game.get_node("WorldManager") as WorldManager
	var mob := load("res://actors/enemies/debug_goku_enemy.tscn").instantiate() as DebugGokuEnemy
	game.add_child(mob)
	mob.set_physics_process(false)
	var destinations: Array = []
	for map in MAPS:
		var folder := "debug" if map == "debug_room" else "world"
		manager.load_world("res://scenes/" + folder + "/" + map + ".tscn")
		var projectile := load("res://combat/projectiles/ki_blast_projectile.tscn").instantiate() as KiBlastProjectile
		projectile.position = Vector2(-1400, -1000)
		game.add_child(projectile)
		projectile.set_physics_process(false)
		var world := manager.world_container.get_child(0)
		for enemy in get_nodes_in_group("enemy"):
			enemy.set_physics_process(false)
			if enemy != mob:
				enemy.collision_layer = 0
		player.position = Vector2(-1000, -1000)
		mob.position = Vector2(-1200, -1000)
		await physics_frame
		await physics_frame
		for name in REQUIRED[map]:
			var prop := world.get_node_or_null(name)
			check(prop != null and not bodies_in(prop).is_empty(), map + "/" + name + " is pass-through")
		for child in world.get_children():
			if child is WorldPortal:
				destinations.append([child.target_scene, child.target_spawn])
		var bodies := bodies_in(world)
		# Isolate each real obstacle so neighboring objects cannot hide a hole.
		for body in bodies:
			body.collision_layer = 0
		for body in bodies:
			body.collision_layer = 1
			for shape_node in body.get_children():
				if shape_node is CollisionPolygon2D and not shape_node.disabled:
					var polygon: PackedVector2Array = shape_node.global_transform * shape_node.polygon
					for i in range(polygon.size()):
						var a := polygon[i]
						var b := polygon[(i + 1) % polygon.size()]
						var midpoint := (a + b) * 0.5
						var normal := (b - a).normalized().orthogonal()
						if not Geometry2D.is_point_in_polygon(midpoint + normal * 16, polygon):
							normal = -normal
						for actor in [player, mob]:
							player.position = Vector2(-1000, -1000)
							mob.position = Vector2(-1200, -1000)
							actor.position = midpoint + normal * 16 - Vector2(0, 8)
							var hit: KinematicCollision2D = actor.move_and_collide(-normal * 80)
							check(hit != null and hit.get_collider() == body, "Crossed coast segment " + str(i))
							sweeps += 1
				if not shape_node is CollisionShape2D or shape_node.disabled or not shape_node.shape is RectangleShape2D:
					continue
				var rect: Rect2 = shape_node.global_transform * shape_node.shape.get_rect()
				for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					var extent: float = rect.size.x * 0.5 if direction.x != 0 else rect.size.y * 0.5
					var start: Vector2 = rect.get_center() + direction * (extent + 24)
					var motion: Vector2 = -direction * (extent * 2 + 48)
					for actor in [player, mob]:
						player.position = Vector2(-1000, -1000)
						mob.position = Vector2(-1200, -1000)
						actor.global_position = start - Vector2(0, 8)
						var hit: KinematicCollision2D = actor.move_and_collide(motion)
						check(hit != null and hit.get_collider() == body, "%s: %s crossed %s from %s" % [map, actor.name, body.get_path(), direction])
						sweeps += 1
					var shot := projectile._cast_against_solids(start, start + motion)
					check(shot.get("collider") == body, "Ki shot crossed " + String(body.get_path()))
					sweeps += 1
			body.collision_layer = 0
		for body in bodies:
			body.collision_layer = 1
		print(map, ": ", bodies.size(), " solid bodies audited")
		if map == "capsule_training_chamber":
			player.position = Vector2(440, 185)
			var before := player.position
			world.get_node("Treadmill").interact(player)
			var training := get_first_node_in_group("training_manager") as TrainingManager
			player._process_treadmill_training(training, Vector2.RIGHT, 0.016)
			check(player.position.is_equal_approx(before), "Treadmill teleported the player into its body")
			training.stop_training()
			var console := world.get_node("SparringConsole") as TrainingSparringConsole
			player.position = console.position + console.spawn_offset
			console._spawn_partner()
			var partner := console._partner as DebugGokuEnemy
			partner.set_physics_process(false)
			check(partner._spawn_position == player.position, "Sparring captured wrong home position")
			await physics_frame
			await physics_frame
			partner._process_respawn_collision(1.0)
			check(partner._respawn_position_is_clear(partner.position), "New sparring partner overlaps player")
			console.interact(player)
			var spawner := EncounterSpawner.new()
			spawner.spawn_on_ready = false
			spawner.enemy_scene = load("res://actors/enemies/debug_goku_enemy.tscn")
			spawner.position = Vector2(600, 400)
			world.add_child(spawner)
			spawner.set_process(false)
			player.position = spawner.position
			check(spawner._spawn_one(), "Encounter spawn failed")
			var spawned := spawner._alive[0] as DebugGokuEnemy
			spawned.set_physics_process(false)
			check(spawned._spawn_position == player.position, "Encounter captured wrong home position")
			await physics_frame
			await physics_frame
			spawned._process_respawn_collision(1.0)
			check(spawned._respawn_position_is_clear(spawned.position), "Encounter spawned inside player")
	for destination in destinations:
		manager.load_world(destination[0])
		for enemy in get_nodes_in_group("enemy"):
			enemy.set_physics_process(false)
		player.position = Vector2(-1000, -1000)
		mob.position = Vector2(-1200, -1000)
		await physics_frame
		await physics_frame
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = player.get_node("CollisionShape2D").shape
		query.transform = Transform2D(0, destination[1] + Vector2(0, 8))
		query.collision_mask = 5
		check(root.world_2d.direct_space_state.intersect_shape(query).is_empty(), "Portal destination inside obstacle: " + str(destination))
	print("All solid scenery: ", "PASS" if failures == 0 else "FAIL", " (", sweeps, " sweeps; ", destinations.size(), " arrivals)")
	game.get_node("SaveManager").delete_save()
	quit(failures)
