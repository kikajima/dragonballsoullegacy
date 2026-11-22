extends SceneTree

# Screenshots of quests, sagas, shop, workbench, Dragon Balls and enemies
# (must run WITH a window):
#   Godot --path . --script res://tools/capture_game_systems.gd -- --out=<dir>

var out_dir := "user://game_systems_captures"
var game: Node
var player: Player
var quests: QuestManager

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	(game.get_node("SaveManager") as SaveManager).save_path = "user://capture_game_systems_save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.6).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	quests = get_first_node_in_group("quest_manager") as QuestManager
	var dialogue := get_first_node_in_group("dialogue_ui") as DialogueBox

	# Tutorial start: tracker and Roshi's marker.
	player.global_position = Vector2(5504 + 414, 2752 + 410)
	await _save("tutorial_start.png")
	var roshi := root.find_child("MasterRoshi", true, false) as MasterRoshiNPC
	roshi.interact(player)
	await create_timer(0.8).timeout
	await _save("tutorial_roshi.png")
	await _close_dialogues(dialogue)
	quests.advance_objective(&"hit:punch", 2)
	await _save("tutorial_tracker.png")

	# Skip to the Saiyan saga.
	for objective in [[&"hit:punch", 5], [&"hit:kick", 3], [&"block", 2], [&"charge_ki_second", 3],
			[&"ki_blast", 5], [&"use_special_attack", 2], [&"defeat:sparring_goku", 1]]:
		quests.advance_objective(objective[0], objective[1])
		await _close_dialogues(dialogue)
	roshi.interact(player)
	await _close_dialogues(dialogue)
	for objective in [&"open_inventory", &"rest", &"fly"]:
		quests.advance_objective(objective)
		await _close_dialogues(dialogue)
	quests.advance_objective(&"reach:west_city")
	var bulma := root.find_child("Bulma", true, false) as WorldNPC
	bulma.interact(player)
	await _close_dialogues(dialogue)
	quests.advance_objective(&"defeat:saibaman", 4)
	bulma.interact(player)
	await _close_dialogues(dialogue)

	# West City: stall and workbench.
	player.global_position = Vector2(1664 + 560, 2112 + 370)
	await _save("west_city_stall.png")
	player.global_position = Vector2(1664 + 1000, 2112 + 330)
	await _save("west_city_workbench.png")
	var wallet := player.get_node("Components/WalletComponent") as WalletComponent
	wallet.add(1500)
	for item in [&"scrap_metal", &"wild_fruit", &"circuit_chip", &"energy_crystal"]:
		player.inventory_component.add_item(item, 3)
	var shop := game.get_node("UIContainer/ShopMenu") as ShopMenu
	shop.open_shop(&"west_city")
	shop._cursor = 3
	shop.refresh()
	await _save("shop_buy.png")
	shop._on_move(Vector2i.RIGHT)
	await _save("shop_sell.png")
	shop.close()
	var craft := game.get_node("UIContainer/CraftingMenu") as CraftingMenu
	craft.open_menu("Capsule Workbench")
	craft.select_recipe(&"battle_vest")
	await _save("crafting.png")
	craft.close()

	# Journal.
	var journal := game.get_node("UIContainer/JournalMenu") as JournalMenu
	journal.open_tab(0)
	await _save("journal_quests.png")
	journal._on_move(Vector2i.RIGHT)
	journal._on_move(Vector2i.DOWN)
	await _save("journal_sagas.png")
	journal.close()

	# Out in the world: radar, wild enemies, Nappa.
	var manager := get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	var ball_tile: Vector2i = manager.get_ground_balls()[0]
	player.global_position = (Vector2(ball_tile) + Vector2(0.5, 3.5)) * 32.0
	await create_timer(0.3).timeout
	await _save("dragon_ball_radar.png")
	manager.collect(0)
	manager.collect(1)
	manager.collect(2)
	journal.open_tab(2)
	await _save("journal_dragon_balls.png")
	journal.close()

	var world := get_first_node_in_group("open_world") as OpenWorld
	var wild := world.get_node("WildEncounters") as WildEncounterDirector
	player.global_position = Vector2(100, 58) * 32.0
	var spawned: Array[DebugGokuEnemy] = []
	for attempt in 20:
		spawned = wild.spawn_group_near(player.global_position)
		if not spawned.is_empty():
			break
	if not spawned.is_empty():
		for enemy in spawned:
			enemy.set_physics_process(false)
		player.global_position = spawned[0].global_position + Vector2(-90, 10)
		await create_timer(0.4).timeout
		await _save("wild_enemies.png")

	quests.start_quest_id(&"saiyan_nappa")
	await _close_dialogues(dialogue)
	(get_first_node_in_group("saga_director") as SagaDirector).update_bosses()
	await process_frame
	for boss in get_nodes_in_group("enemy"):
		if boss.has_meta(SagaDirector.BOSS_META):
			boss.set_physics_process(false)
			player.global_position = (boss as Node2D).global_position + Vector2(-80, 20)
	await create_timer(0.4).timeout
	await _save("boss_nappa.png")

	# Shenron.
	for index in 7:
		manager.collect(index)
	journal.open_tab(2)
	journal.summon_shenron()
	await create_timer(1.2).timeout
	await _save("shenron.png")
	var shenron := game.get_node("UIContainer/ShenronWishMenu") as ShenronWishMenu
	shenron.make_wish(&"riches")
	await _save("shenron_granted.png")
	shenron.close()

	(game.get_node("SaveManager") as SaveManager).delete_save()
	print("GAME SYSTEMS CAPTURES ", out_dir)
	quit(0)

func _close_dialogues(dialogue: DialogueBox) -> void:
	var director := get_first_node_in_group("saga_director") as SagaDirector
	for i in 120:
		if not dialogue.is_open() and not director.has_pending_story():
			return
		if dialogue.is_open():
			dialogue.close_dialogue()
		await process_frame

func _save(file: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file))
