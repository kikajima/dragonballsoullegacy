extends SceneTree

var failures: int = 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	# Checkpoints may autosave before the save/load assertion at the end.
	(game.get_node("SaveManager") as SaveManager).save_path = "res://audit-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.3).timeout
	var player := get_first_node_in_group("player") as Player
	var enemy := get_first_node_in_group("enemy") as DebugGokuEnemy
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.global_position = Vector2(500, 368)
	enemy.global_position = Vector2(610, 368)
	enemy.health_component.max_health = 10000
	enemy.health_component.restore_full()
	player.facing_component.update_from_direction(Vector2.RIGHT)
	var special := player.special_attack_component
	special.start_cast(&"right", Vector2.RIGHT)
	for step in range(75):
		special.tick_cast(player, 1.0 / 60.0, true)
		player.animation_controller.update_visual(special.get_cast_state(), &"right", 1.0 / 60.0)
		await physics_frame
	var beam := special._active_beam
	print("REAL BEAM origin=", beam.global_position, " target=", enemy.global_position,
		" length=", beam._resolved_length, " width=", beam._beam_width,
		" health=", enemy.health_component.current_health)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://audit-gameplay.png")
	var sheet := DmiSpriteSheet.load_file("res://assets/sprites/effects/hu2/Effects.dmi")
	for state in [&"KameStart", &"KameMid", &"KameHead", &"KameHit"]:
		var bounds := Rect2i()
		for frame in range(sheet.get_frame_count(state)):
			var texture := sheet.get_frame_texture(state, &"right", frame)
			var used := texture.get_image().get_used_rect()
			bounds = used if frame == 0 else bounds.merge(used)
		print(state, " alpha bounds=", bounds)
	# Keep the actual actor death/respawn behavior instead of a dummy area.
	enemy.health_component.take_damage(10000)
	await physics_frame
	await physics_frame
	print("AFTER REAL TARGET DEATH length=", beam._resolved_length, " stopping=", beam._stopping)
	_check(not beam._stopping and beam._resolved_length > 110, "Beam must continue beyond a defeated real actor")
	var ki_before: float = special.ki_component.current_ki
	special.tick_cast(player, 1.0 / 60.0, true)
	_check(special.is_casting() and special.ki_component.current_ki < ki_before, "Held beam must keep casting and draining Ki after a defeat")
	special.tick_cast(player, 1.0, false)
	_check(not special.is_casting(), "Releasing the button must still end the beam")
	for node_name in ["CombatHUD", "SpecialStatusHUD", "LocationBanner", "NotificationFeed"]:
		var control := game.get_node("UIContainer/" + node_name) as Control
		print("HUD ", node_name, " rect=", control.get_global_rect())
	var health_rect := (game.get_node("UIContainer/CombatHUD/PlayerPanel") as Control).get_global_rect()
	_check(not health_rect.intersects((game.get_node("UIContainer/SpecialStatusHUD") as Control).get_global_rect()), "Special status overlaps HP")
	_check(not health_rect.intersects((game.get_node("UIContainer/LocationBanner") as Control).get_global_rect()), "Location banner overlaps HP")
	# Short charge followed by release must actually damage a real enemy.
	enemy.queue_free()
	await process_frame
	enemy = load("res://actors/enemies/debug_goku_enemy.tscn").instantiate() as DebugGokuEnemy
	enemy.position = Vector2(600, 368)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health_component.max_health = 1000
	enemy.health_component.restore_full()
	player.ability_loadout_component.start_cooldown(&"kamehameha", 0.0)
	player.ki_component.restore_full()
	_check(special.start_cast(&"right", Vector2.RIGHT), "Short cast must start")
	for step in range(20):
		special.tick_cast(player, 1.0 / 60.0, true)
		await physics_frame
	for step in range(20):
		special.tick_cast(player, 1.0 / 60.0, false)
		await physics_frame
	_check(enemy.health_component.current_health < 1000, "Released charge must deal damage")
	_check(not special.is_casting(), "Released charge must finish")
	# Hitbox activated while already overlapping an invulnerable target.
	var hitbox := player.attack_hitbox
	hitbox.global_position = enemy.global_position
	enemy.hurtbox.grant_invulnerability(0.04)
	var health_before: int = enemy.health_component.current_health
	hitbox.set_active(true)
	for step in range(12):
		await physics_frame
	hitbox.set_active(false)
	_check(enemy.health_component.current_health == health_before - hitbox.damage, "Overlapping melee must hit once after invulnerability expires")
	enemy.guard_component.set_guarding(true)
	enemy.guard_component._guard_time = 1.0
	_check(enemy.guard_component.resolve_damage(20, Vector2.ZERO, Vector2.LEFT, &"left") < 20, "Front guard must reduce damage")
	_check(enemy.guard_component.resolve_damage(20, Vector2.ZERO, Vector2.RIGHT, &"left") == 20, "Rear hit must bypass guard")
	enemy.queue_free()
	await process_frame
	# Load every playable map, exercise real world transitions and capture UI.
	var manager := game.get_node("WorldManager") as WorldManager
	var spawns := {
		"kame_house_interior": Vector2(272, 305),
		"capsule_training_chamber": Vector2(400, 340),
		"west_city_outskirts": Vector2(240, 185),
		"rocky_wastes": Vector2(190, 360),
		"kame_island": Vector2(480, 405),
	}
	for map in ["kame_house_interior", "capsule_training_chamber", "west_city_outskirts", "rocky_wastes", "kame_island"]:
		var stray := load("res://combat/projectiles/ki_blast_projectile.tscn").instantiate() as Node
		game.add_child(stray)
		_check(manager.load_world("res://scenes/world/" + map + ".tscn", spawns[map], true), "Map failed: " + map)
		await process_frame
		_check(not is_instance_valid(stray), "Projectile survived world change")
		for actor in get_nodes_in_group("enemy"):
			actor.set_physics_process(false)
		await create_timer(0.1).timeout
		_check(game.get_node("WorldContainer").get_child_count() == 1, "Outgoing map remained active")
		var world := game.get_node("WorldContainer").get_child(0)
		if map == "kame_house_interior":
			_check(world.get_node("Terrain/FloorTiles").get_child_count() > 0, "House floor tiles missing")
			_check(world.get_node("Background").z_index < -10, "Background occludes floor")
		if map == "kame_island":
			var shore_query := PhysicsRayQueryParameters2D.create(Vector2(480, 470), Vector2(480, 510), 1)
			var shore := player.get_world_2d().direct_space_state.intersect_ray(shore_query)
			_check(not shore.is_empty() and shore.position.y > 478 and shore.position.y < 482, "Shore collision must follow visible beach")
			var dock_query := PhysicsRayQueryParameters2D.create(Vector2(670, 426), Vector2(740, 426), 1)
			var dock_hit := player.get_world_2d().direct_space_state.intersect_ray(dock_query)
			if not dock_hit.is_empty():
				print("DOCK BLOCKER: ", dock_hit)
			_check(dock_hit.is_empty(), "Dock access must be walkable")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://audit-" + map + ".png")
		print("MAP PASS: ", map)
	var sensor := player.interaction_sensor
	var previous_candidates := sensor._candidates.duplicate()
	var first := WorldPortal.new()
	var second := WorldPortal.new()
	game.add_child(first)
	game.add_child(second)
	first.position = player.global_position + Vector2(-10, 0)
	second.position = player.global_position + Vector2(20, 0)
	sensor._candidates.assign([first, second])
	sensor._physics_process(0.0)
	_check(sensor._reported_target == first, "Prompt must select nearest interaction")
	player.position.x += 18
	sensor._physics_process(0.0)
	_check(sensor._reported_target == second, "Prompt must update when walking between existing overlaps")
	sensor._candidates.assign(previous_candidates)
	first.queue_free()
	second.queue_free()
	# Save/load uses a disposable QA slot, never the player's actual save.
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-save.json"
	player.global_position = Vector2(480, 405)
	_check(saves.save_game(), "QA save failed")
	player.global_position = Vector2(400, 400)
	_check(saves.load_game(), "QA load failed")
	_check(player.global_position.is_equal_approx(Vector2(480, 405)), "Position did not restore")
	saves.delete_save()
	print("Gameplay integration: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
