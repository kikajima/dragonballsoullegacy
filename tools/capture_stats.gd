extends SceneTree

# Screenshots of the character stats features (must run WITH a window):
#   Godot --path . --script res://tools/capture_stats.gd -- --out=<dir>
# status.png, analyze.png (with ki sense markers), meditate.png,
# library.png, university.png, lab.png, gravity.png, dodge.png

const ENEMY_SCENE := preload("res://actors/enemies/debug_goku_enemy.tscn")

var out_dir := "user://stats_captures"
var game: Node2D
var player: Player
var world: WorldManager

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-stats-capture-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.4).timeout
	player = get_first_node_in_group("player") as Player
	world = get_first_node_in_group("world_manager") as WorldManager
	var stats := player.character_stats
	stats.set_level(CharacterStatsComponent.STRENGTH, 23)
	stats.set_level(CharacterStatsComponent.AGILITY, 14)
	stats.set_level(CharacterStatsComponent.VIGOR, 31)
	stats.set_level(CharacterStatsComponent.WISDOM, 9)
	stats.set_level(CharacterStatsComponent.INTELLIGENCE, 27)
	stats.add_xp(CharacterStatsComponent.WISDOM, 300.0)

	var menu := get_first_node_in_group("status_menu") as StatusMenu
	menu.open()
	await _save("status.png")
	menu.close()

	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	var near := ENEMY_SCENE.instantiate() as DebugGokuEnemy
	var container: Node = get_first_node_in_group("world_container")
	(container if container != null else game).add_child(near)
	near.global_position = player.global_position + Vector2(50, 0)
	var far := ENEMY_SCENE.instantiate() as DebugGokuEnemy
	near.get_parent().add_child(far)
	far.global_position = player.global_position + Vector2(-60, 230)
	near.set_physics_process(false)
	far.set_physics_process(false)
	await create_timer(0.2).timeout
	near.health_component.take_damage(9)
	player.analyze_nearest()
	await _save("analyze.png")

	player.set_physics_process(false)
	player.start_meditation()
	for i in 20:
		player._process_focus(Vector2.ZERO, 1.0 / 60.0)
		await physics_frame
	await _save("meditate.png")
	player.stop_focus()
	near.queue_free()
	far.queue_free()
	player.set_physics_process(true)

	await _visit("res://scenes/world/west_city_outskirts.tscn", Vector2(352, 232), "library.png")
	await _visit("res://scenes/world/west_city_outskirts.tscn", Vector2(1010, 586), "university.png")
	await _visit("res://scenes/world/capsule_training_chamber.tscn", Vector2(560, 474), "lab.png")

	var training := get_first_node_in_group("training_manager") as TrainingManager
	training.set_gravity(500.0)
	training.set_prompt("GRAVITY 500x  (BODY LIMIT %s)  TOO HEAVY!" % TrainingManager.format_gravity(training.get_body_limit()))
	await create_timer(0.4).timeout
	await _save("gravity.png")
	training.set_gravity(1.0)

	player.play_evade_blink()
	await create_timer(0.05).timeout
	await _save("dodge.png")
	saves.delete_save()
	print("STATS CAPTURES ", out_dir)
	quit(0)

func _visit(scene: String, at: Vector2, file: String) -> void:
	world.load_world(scene, at, true)
	await create_timer(0.6).timeout
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	player.facing_component.update_from_direction(Vector2.UP)
	var spot: StudySpot = null
	for node in get_nodes_in_group("study_spot"):
		if spot == null or (node as Node2D).global_position.distance_to(at) < spot.global_position.distance_to(at):
			spot = node
	if spot != null:
		spot.interact(player)
	await create_timer(0.4).timeout
	await _save(file)
	player.stop_focus()

func _save(file: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file))
