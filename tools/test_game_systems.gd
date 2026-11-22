extends SceneTree

# Quests, sagas, the Kame Island tutorial, wild enemies, saga bosses, shop,
# crafting, Dragon Balls and wishes, and their save data.
#   Godot --headless --path . --script res://tools/test_game_systems.gd

var failures := 0
var game: Node
var player: Player
var quests: QuestManager
var dialogue: DialogueBox
var wallet: WalletComponent

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
		print("FAIL: ", message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	(game.get_node("SaveManager") as SaveManager).save_path = "user://test_game_systems_save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.3).timeout
	player = get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	quests = get_first_node_in_group("quest_manager") as QuestManager
	dialogue = get_first_node_in_group("dialogue_ui") as DialogueBox
	wallet = player.get_node("Components/WalletComponent") as WalletComponent

	await test_items()
	await test_tutorial()
	await test_saiyan_start()
	await test_wild_enemies()
	await test_bosses()
	await test_shop()
	await test_crafting()
	await test_dragon_balls()
	await test_save_roundtrip()
	test_legacy_saves()

	(game.get_node("SaveManager") as SaveManager).delete_save()
	print("Game systems: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)

func close_dialogues() -> void:
	for i in 120:
		if not dialogue.is_open() and not (get_first_node_in_group("saga_director") as SagaDirector).has_pending_story():
			return
		if dialogue.is_open():
			dialogue.close_dialogue()
		await process_frame
	check(false, "Dialogues kept opening")

func talk_to(npc_id: StringName, speaker: String) -> void:
	QuestTalk.talk(player, npc_id, speaker, ["(fallback)"])

# --- Items -------------------------------------------------------------------

func test_items() -> void:
	for item_id in [&"rice_ball", &"scrap_metal", &"dragon_radar", &"weighted_vest", &"senzu_bean", &"travel_bag"]:
		var data := ItemCatalog.get_item(item_id)
		check(data != null, "Item missing: %s" % item_id)
		if data != null:
			check(data.icon != null, "Item icon missing: %s" % item_id)
			check(data.get_buy_price() > 0, "Item has no price: %s" % item_id)
	check(ItemCatalog.get_item(&"weighted_vest").defense_bonus == 2, "Vest defense")

	# Food heals; armour takes damage off.
	player.health_component.take_damage(60)
	var before := player.health_component.current_health
	player.inventory_component.add_item(&"rice_ball", 1)
	check(player.use_inventory_item(&"rice_ball"), "Rice ball usable when hurt")
	check(player.health_component.current_health == mini(before + 40, player.health_component.max_health), "Rice ball heals 40")
	player.health_component.restore_full()
	check(not player.consumable_component.use_item(&"rice_ball"), "No rice ball left")
	var plain := player.modify_incoming_damage(10, player.global_position + Vector2(0, -50))
	player.inventory_component.add_item(&"weighted_vest", 1)
	check(player.equipment_component.equip(&"weighted_vest"), "Equip vest")
	var armoured := player.modify_incoming_damage(10, player.global_position + Vector2(0, -50))
	check(plain == 0 or armoured == maxi(plain - 2, 1), "Vest takes 2 off a hit (%d -> %d)" % [plain, armoured])
	player.equipment_component.unequip(EquipmentComponent.SLOT_ARMOR)
	player.inventory_component.remove_item(&"weighted_vest", 1)

	# Pickups show the item icon.
	var pickup := (load("res://world/pickups/pickup_actor.tscn") as PackedScene).instantiate() as PickupActor
	game.add_child(pickup)
	pickup.global_position = Vector2(-500, -500)
	pickup.configure_item(&"scrap_metal", 1)
	check(pickup.get_node_or_null("Visual/Icon") != null, "Pickup shows the item icon")
	pickup.queue_free()

# --- Tutorial ----------------------------------------------------------------

func test_tutorial() -> void:
	check(quests.is_active(&"kame_welcome"), "New game starts the tutorial")
	var tracker := game.get_node("UIContainer/QuestTracker") as QuestTracker
	await process_frame
	check(tracker.visible and tracker.title_label.text == "Welcome to Kame Island", "Tracker shows the tutorial")
	var roshi := get_first_node_in_group("npc").get_tree().root.find_child("MasterRoshi", true, false) as MasterRoshiNPC
	check(roshi != null and roshi.get_node_or_null("QuestMarker").visible, "Roshi shows a quest marker")

	roshi.interact(player)
	check(quests.is_completed(&"kame_welcome"), "Talking to Roshi completes the welcome")
	check(quests.is_active(&"kame_fundamentals"), "Fundamentals start")
	check(dialogue.is_open(), "Roshi explains the fundamentals")
	await close_dialogues()

	# Real hooks from the player.
	player._on_hit_blocked(10, 5)
	player._on_hit_blocked(10, 5)
	quests.advance_objective(&"hit:punch", 5)
	check(quests.is_active(&"kame_fundamentals"), "Fundamentals need kicks too")
	quests.advance_objective(&"hit:kick", 3)
	check(quests.is_completed(&"kame_fundamentals"), "Fundamentals done")
	await close_dialogues()
	quests.advance_objective(&"charge_ki_second", 3)
	for i in 5:
		player._on_ki_blast_fired(&"down", 0)
	check(quests.is_completed(&"kame_ki"), "Ki control done through ki blasts")
	await close_dialogues()
	quests.advance_objective(&"use_special_attack", 2)
	check(quests.is_active(&"kame_sparring"), "Sparring starts")
	await close_dialogues()

	var sparring := root.find_child("TrainingFighter", true, false) as DebugGokuEnemy
	check(sparring != null and sparring.enemy_id == &"sparring_goku", "Sparring partner has its id")
	sparring.health_component.take_damage(99999)
	await process_frame
	check(quests.is_ready(&"kame_sparring"), "Sparring waits for Roshi")
	check(roshi.get_node("QuestMarker").visible and (roshi.get_node("QuestMarker/Label") as Label).text == "?",
		"Roshi shows ? when the quest is ready")
	var senzu_before := player.inventory_component.get_quantity(&"senzu_bean")
	roshi.interact(player)
	check(quests.is_completed(&"kame_sparring"), "Reported to Roshi")
	check(player.inventory_component.get_quantity(&"senzu_bean") == senzu_before + 1, "Senzu reward")
	check(dialogue.is_open(), "Roshi praises the win")
	await close_dialogues()

	var inventory_menu := game.get_node("UIContainer/InventoryMenu") as InventoryMenu
	inventory_menu.open()
	inventory_menu.close()
	quests.advance_objective(&"rest")
	check(quests.is_active(&"kame_flight"), "Flight lesson starts")
	await close_dialogues()
	player.toggle_flight()
	check(quests.is_active(&"kame_journey"), "Flying starts the journey")
	player.flight_component.land_immediately()
	await close_dialogues()

	# Reaching West City.
	player.global_position = QuestCatalog.WEST_CITY * 32.0
	await create_timer(0.6).timeout
	check(quests.is_ready(&"kame_journey"), "Reaching West City")
	var arrow_state := quests.get_tracked_quest()
	check(str(arrow_state.get("status", "")) == "ready", "Tracker follows the journey")

func test_saiyan_start() -> void:
	var bulma := root.find_child("Bulma", true, false) as WorldNPC
	check(bulma != null and bulma.npc_id == &"bulma", "Bulma in West City")
	bulma.interact(player)
	check(quests.is_completed(&"kame_journey"), "Bulma ends the tutorial")
	check(quests.get_saga_progress(&"kame_training")["completed"], "Tutorial saga complete")
	check(quests.is_active(&"saiyan_pod"), "Saiyan saga starts")
	await close_dialogues()
	quests.advance_objective(&"defeat:saibaman", 4)
	bulma.interact(player)
	check(player.inventory_component.get_quantity(&"dragon_radar") == 1, "Bulma gives the Dragon Radar")
	check(quests.is_active(&"saiyan_raditz"), "Raditz quest starts")
	await close_dialogues()
	# The side quests offered afterwards.
	check(QuestCatalog.offers_for(&"bulma", quests).has(&"bulma_parts"), "Bulma offers spare parts")
	bulma.interact(player)
	await close_dialogues()
	check(quests.is_active(&"bulma_parts"), "Spare parts accepted")
	check(str(quests.get_tracked_quest().get("quest_id", "")) == "saiyan_raditz", "Story quest stays tracked")
	player.inventory_component.add_item(&"scrap_metal", 4)
	await process_frame
	check(quests.is_ready(&"bulma_parts"), "Collect objective follows the bag")
	bulma.interact(player)
	await close_dialogues()
	check(quests.is_completed(&"bulma_parts"), "Spare parts reported")
	check(player.inventory_component.get_quantity(&"scrap_metal") == 0, "Collected items handed over")
	check(player.inventory_component.get_quantity(&"weighted_armbands") == 1, "Armbands reward")

# --- Enemies -----------------------------------------------------------------

func test_wild_enemies() -> void:
	var world := get_first_node_in_group("open_world") as OpenWorld
	var director := world.get_node("WildEncounters") as WildEncounterDirector
	check(director.is_enabled(), "Wild enemies after the tutorial")
	player.global_position = Vector2(100, 60) * 32.0
	check(not director.can_spawn_at(QuestCatalog.WEST_CITY * 32.0), "No spawns in West City")
	var spawned: Array[DebugGokuEnemy] = []
	for attempt in 10:
		spawned = director.spawn_group_near(player.global_position)
		if not spawned.is_empty():
			break
	check(not spawned.is_empty(), "Wild group spawned")
	if spawned.is_empty():
		return
	await process_frame
	var enemy := spawned[0]
	check(enemy.is_wild and enemy.is_in_group("wild_enemy"), "Wild flag and group")
	check(enemy.sprite.sprite_frames != null, "Wild enemy has its sprite")
	check(world.terrain.is_walkable(enemy.global_position), "Wild enemy on walkable ground")
	quests.start_quest_id(&"saiyan_training")
	await close_dialogues()
	var before := int(quests.get_quest(&"saiyan_training")["objectives"][0]["progress"])
	enemy.loot = [[&"scrap_metal", 1.0, 1, 1]]
	enemy.health_component.take_damage(99999)
	await process_frame
	await process_frame
	check(int(quests.get_quest(&"saiyan_training")["objectives"][0]["progress"]) == before + 1, "Wild defeat counts")
	var drops := get_nodes_in_group("pickup").filter(func(p: Node) -> bool:
		return (p as PickupActor).item_id == &"scrap_metal")
	check(not drops.is_empty(), "Wild enemy drops its loot")
	await create_timer(2.0).timeout
	check(not is_instance_valid(enemy), "Wild enemy does not respawn")
	for other in spawned:
		if is_instance_valid(other):
			other.queue_free()

func test_bosses() -> void:
	var director := get_first_node_in_group("saga_director") as SagaDirector
	quests.start_quest_id(&"saiyan_nappa")
	await close_dialogues()
	director.update_bosses()
	await process_frame
	var bosses := get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e.has_meta(SagaDirector.BOSS_META))
	check(bosses.size() == 1, "Nappa appears (%d bosses)" % bosses.size())
	if bosses.is_empty():
		return
	var nappa := bosses[0] as DebugGokuEnemy
	check(nappa.enemy_id == &"nappa" and nappa.display_name == "Nappa", "Boss is Nappa")
	check(nappa.global_position.distance_to(QuestCatalog.GINGER_TOWN * 32.0) < 32.0 * 12.0, "Nappa at Ginger Town")
	director.update_bosses()
	check(get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e.has_meta(SagaDirector.BOSS_META)).size() == 1,
		"No duplicate boss")
	nappa.health_component.take_damage(99999)
	await process_frame
	check(quests.is_completed(&"saiyan_nappa"), "Defeating Nappa completes the quest")
	check(quests.is_active(&"saiyan_vegeta"), "Vegeta is next")
	await close_dialogues()
	director.update_bosses()
	await process_frame
	var vegeta := get_nodes_in_group("enemy").filter(func(e: Node) -> bool:
		return e.has_meta(SagaDirector.BOSS_META) and not e.is_queued_for_deletion() and e.get("enemy_id") == &"vegeta")
	check(vegeta.size() == 1, "Vegeta appears")
	# Every boss of every quest exists in the catalog.
	for quest_id in QuestCatalog.QUESTS:
		for boss: Dictionary in QuestCatalog.QUESTS[quest_id].get("bosses", []):
			check(EnemyCatalog.has_enemy(boss["enemy"]), "Unknown boss %s" % boss["enemy"])
			check(FileAccess.file_exists(EnemyCatalog.CHARACTERS + EnemyCatalog.ENEMIES[boss["enemy"]]["dmi"] + ".dmi"),
				"Boss sprite missing: %s" % boss["enemy"])
	for enemy_id in EnemyCatalog.ENEMIES:
		check(FileAccess.file_exists(EnemyCatalog.CHARACTERS + EnemyCatalog.ENEMIES[enemy_id]["dmi"] + ".dmi"),
			"Enemy sprite missing: %s" % enemy_id)
	# The saga chain reaches the end.
	var quest_id: StringName = QuestCatalog.FIRST_QUEST
	var steps := 0
	while quest_id != &"" and steps < 100:
		check(QuestCatalog.has_quest(quest_id), "Chain broken at %s" % quest_id)
		quest_id = QuestCatalog.QUESTS[quest_id].get("next", &"")
		steps += 1
	var saga_quests := 0
	for saga: Dictionary in QuestCatalog.SAGAS:
		saga_quests += (saga["quests"] as Array).size()
	check(steps == saga_quests, "Every saga quest is on the chain (%d of %d)" % [steps, saga_quests])

# --- Shop and crafting -------------------------------------------------------

func test_shop() -> void:
	var menu := game.get_node("UIContainer/ShopMenu") as ShopMenu
	wallet.current_amount = 100
	check(menu.open_shop(&"west_city"), "Shop opens")
	check(get_tree_paused(), "Shop pauses the game")
	check(menu.buy(&"rice_ball"), "Buy a rice ball")
	check(wallet.current_amount == 85, "Rice ball costs 15")
	check(player.inventory_component.get_quantity(&"rice_ball") >= 1, "Rice ball in the bag")
	check(not menu.buy(&"dragon_radar"), "Can't afford the radar")
	check(menu.sell(&"rice_ball"), "Sell it back")
	check(wallet.current_amount == 91, "Sold for 6")
	menu.close()
	check(not get_tree_paused(), "Shop unpauses")
	var stall := root.find_child("MarketStall", true, false) as ServicePoint
	check(stall != null and stall.get_interaction_label().begins_with("Shop"), "Market stall in West City")
	var ginger := root.find_child("Stall_ginger_town", true, false) as ServicePoint
	check(ginger != null, "Ginger Town stall")
	if ginger != null:
		var world := get_first_node_in_group("open_world") as OpenWorld
		check(world.terrain.is_walkable(ginger.global_position), "Ginger Town stall on ground")

func test_crafting() -> void:
	var menu := game.get_node("UIContainer/CraftingMenu") as CraftingMenu
	quests.start_quest_id(&"bulma_workbench")
	await close_dialogues()
	wallet.current_amount = 50
	player.inventory_component.add_item(&"scrap_metal", 3)
	check(menu.open_menu("Workbench"), "Workbench opens")
	menu.select_recipe(&"weighted_vest")
	check(not menu.craft_selected(), "Vest needs 4 scrap")
	menu.select_recipe(&"weighted_armbands")
	var armbands := player.inventory_component.get_quantity(&"weighted_armbands")
	check(menu.craft_selected(), "Craft armbands")
	check(player.inventory_component.get_quantity(&"weighted_armbands") == armbands + 1, "Armbands crafted")
	# 3 used, 2 back as the workbench quest's reward.
	check(player.inventory_component.get_quantity(&"scrap_metal") == 2, "Scrap used")
	check(wallet.current_amount == 30, "Crafting cost 20 Zeni")
	check(quests.is_completed(&"bulma_workbench"), "Craft objective")
	menu.close()
	await close_dialogues()
	for recipe: Dictionary in RecipeCatalog.RECIPES:
		check(ItemCatalog.has_item(recipe["output"]), "Recipe output exists: %s" % recipe["id"])
		for item_id in recipe["inputs"]:
			check(ItemCatalog.has_item(item_id), "Recipe input exists: %s" % item_id)
	var workbench := root.find_child("CapsuleWorkbench", true, false) as ServicePoint
	check(workbench != null, "Workbench in West City")

# --- Dragon Balls ------------------------------------------------------------

func test_dragon_balls() -> void:
	var manager := get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	var world := get_first_node_in_group("open_world") as OpenWorld
	var ground := manager.get_ground_balls()
	check(ground.size() == 7, "Seven balls on Earth (%d)" % ground.size())
	for index in ground:
		var tile: Vector2i = ground[index]
		check(world.terrain.is_walkable_cell(tile), "Ball %d on walkable ground" % index)
		check(world.region_at((Vector2(tile) + Vector2(0.5, 0.5)) * 32.0) == null, "Ball %d outside regions" % index)
	await process_frame
	check(get_nodes_in_group("dragon_ball").size() == 7, "Seven balls drawn")

	var radar := game.get_node("UIContainer/DragonRadarHUD") as DragonRadarHUD
	player.global_position = Vector2(100, 60) * 32.0
	await process_frame
	check(radar.visible, "Radar shows with the Dragon Radar in the bag")

	quests.start_quest_id(&"krillin_dragon_ball")
	await close_dialogues()
	for index in 7:
		check(manager.collect(index), "Collect ball %d" % index)
	check(quests.is_completed(&"krillin_dragon_ball"), "Dragon Ball objective")
	check(manager.can_summon(), "All seven gathered")
	await process_frame
	check(get_nodes_in_group("dragon_ball").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(),
		"Balls leave the map")

	var journal := game.get_node("UIContainer/JournalMenu") as JournalMenu
	check(journal.open_tab(2), "Journal opens on the Dragon Balls")
	var shenron := game.get_node("UIContainer/ShenronWishMenu") as ShenronWishMenu
	check(journal.summon_shenron(), "Shenron summoned")
	check(shenron.is_open() and not journal.is_open(), "Wish screen open")
	var zeni := wallet.current_amount
	check(shenron.make_wish(&"riches"), "Wish granted")
	check(wallet.current_amount == zeni + 10000, "Riches wish")
	check(manager.held_count() == 0 and manager.is_stone(), "Balls scatter and turn to stone")
	check(not manager.collect(0), "Stone balls can't be taken")
	check(manager.get_ground_balls().size() == 7, "Balls placed again")
	shenron.close()
	check(not get_tree_paused(), "Wish screen unpauses")

	var stats := player.get_stats()
	var strength := stats.get_level(CharacterStatsComponent.STRENGTH)
	manager._stone_left = 0.0
	for index in 7:
		manager.collect(index)
	check(manager.grant_wish(&"power"), "Power wish")
	check(stats.get_level(CharacterStatsComponent.STRENGTH) == strength + 3, "Power wish raises stats")
	manager._stone_left = 0.0

	# The journal tabs draw without errors.
	for tab in 3:
		journal.open_tab(tab)
		await process_frame
		journal._on_move(Vector2i.DOWN)
		await process_frame
		journal.close()

# --- Save --------------------------------------------------------------------

func test_save_roundtrip() -> void:
	await close_dialogues()
	var save := game.get_node("SaveManager") as SaveManager
	var manager := get_first_node_in_group("dragon_ball_manager") as DragonBallManager
	manager.collect(2)
	var tiles := manager.get_ground_balls()
	var progress := quests.get_quest(&"saiyan_training")
	check(save.save_game(), "Save")
	manager.collect(4)
	quests.advance_objective(&"defeat:wild", 2)
	check(save.load_game(), "Load")
	await process_frame
	check(manager.is_held(2) and not manager.is_held(4), "Dragon Balls restored")
	check(manager.get_ground_balls() == tiles, "Ball places restored")
	check(quests.get_quest(&"saiyan_training")["objectives"] == progress["objectives"], "Quest progress restored")
	check(quests.is_completed(&"kame_journey") and quests.is_completed(&"bulma_parts"), "Completed quests restored")
	await close_dialogues()

func test_legacy_saves() -> void:
	var old := QuestManager.new()
	old.start_tutorial = false
	root.add_child(old)
	old.load_state({"quests": {
		"roshi_special_training": {"quest_id": "roshi_special_training", "title": "Roshi's Special Technique Training",
			"objective_id": "use_special_attack", "objective_text": "Use special techniques",
			"progress": 3, "target_count": 3, "status": "completed"},
		"capsule_training_circuit": {"quest_id": "capsule_training_circuit", "title": "Capsule Training Circuit",
			"objective_id": "try_training_mode", "objective_text": "Use a different training system",
			"progress": 1, "target_count": 4, "status": "active"},
	}})
	check(old.is_completed(&"kame_sparring"), "Old finished training skips the tutorial")
	check(old.is_active(&"kame_journey"), "Old saves continue to West City")
	var circuit := old.get_quest(&"capsule_training_circuit")
	check((circuit.get("objectives", []) as Array).size() == 1 and int(circuit["objectives"][0]["progress"]) == 1,
		"Single-objective quests upgraded")
	old.advance_objective(&"try_training_mode", 3)
	check(old.is_completed(&"capsule_training_circuit"), "Upgraded quest still completes")

	old.load_state({"quests": {"training_basics": {"quest_id": "training_basics", "status": "active",
		"objective_id": "defeat_training_dummy", "progress": 1, "target_count": 2}}})
	check(not old.is_started(&"training_basics") and old.is_active(&"kame_welcome"), "Unfinished old training restarts the tutorial")
	old.queue_free()

func get_tree_paused() -> bool:
	return paused
