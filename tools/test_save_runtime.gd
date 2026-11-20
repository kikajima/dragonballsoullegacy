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
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-runtime-save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.2).timeout
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	player.health_component.restore_full()
	player.ki_component.restore_full()
	check(saves.save_game(), "Create healthy QA save")
	var healthy_save := FileAccess.get_file_as_string(saves.save_path)
	var special := player.special_attack_component
	check(special.start_cast(&"right", Vector2.RIGHT), "Start real Kamehameha")
	for frame in range(65):
		special.tick_cast(player, 1.0 / 60.0, true)
		await physics_frame
	check(is_instance_valid(special._active_beam), "Test requires a live beam")
	player.status_effect_component.apply_status(&"stun", 60)
	player.combo_tracker_component.register_hit(10)
	player.knockback_component.start(player, player.position - Vector2.RIGHT)
	player.ability_loadout_component.start_cooldown(&"burning_attack", 30)
	player._hurt_time_left = 5.0
	var pause_menu := game.get_node("UIContainer/PauseMenu") as PauseMenu
	pause_menu._pause()
	check(saves.load_game(), "Load via paused menu in the same map")
	check(paused, "Loading must preserve menu pause")
	check(not special.is_casting(), "Old cast survived loading")
	check(not player.status_effect_component.has_status(&"stun"), "Old stun survived loading")
	check(not player.knockback_component.is_active(), "Old knockback survived loading")
	check(player.combo_tracker_component.hit_count == 0, "Old combo survived loading")
	check(is_zero_approx(player._hurt_time_left), "Old hurt timer survived loading")
	check(is_zero_approx(player.ability_loadout_component.get_cooldown_left(&"burning_attack")), "Unsaved cooldown survived loading")
	await process_frame
	check(get_nodes_in_group("active_special_beam").is_empty(), "Old beam survived loading")
	check(player.health_component.current_health == 100 and is_equal_approx(player.ki_component.current_ki, 100), "Saved resources were not restored exactly")
	pause_menu._resume()
	var dash := game.get_node("PlayerDashSystem") as PlayerDashSystem
	dash.set_process(false)
	var speed := player.movement_component.move_speed
	Input.action_press("move_right")
	dash._try_start_dash()
	Input.action_release("move_right")
	check(dash._dash_left > 0.0, "Test requires active dash")
	check(saves.load_game(), "Load during dash")
	check(is_zero_approx(dash._dash_left) and is_zero_approx(dash._cooldown_left), "Dash runtime survived loading")
	check(is_equal_approx(player.movement_component.move_speed, speed), "Loading left dash speed multiplier active")
	var training := get_first_node_in_group("training_manager") as TrainingManager
	check(training.start_treadmill(player.global_position + Vector2(100, 0)), "Start treadmill session")
	training.register_success()
	check(saves.load_game(), "Load during treadmill training")
	check(not training.is_treadmill_active() and training.session_xp == 0, "Unsaved training survived loading")
	var world := get_first_node_in_group("world_manager") as WorldManager
	world.load_world_with_transition("res://scenes/world/kame_house_interior.tscn", Vector2(240, 185), true)
	check(world.is_transitioning(), "Test requires a pending world transition")
	check(not saves.load_game(), "Loading must not race world travel")
	pause_menu._load()
	check(pause_menu.status_label.text.contains("troca de mapa"), "Menu must explain a travel rejection")
	await create_timer(0.8).timeout
	check(not world.is_transitioning(), "Travel must complete after a rejected load")
	# A lethal hit starts an asynchronous respawn. Saving/loading during that
	# interval must not replace the healthy save with zero HP or race its fade.
	pause_menu._resume()
	player.health_component.take_damage(player.health_component.max_health)
	check(player._respawning, "Test requires real respawn")
	check(not saves.save_game(), "Saving during defeat should be rejected")
	check(FileAccess.get_file_as_string(saves.save_path) == healthy_save, "Defeat overwrote the healthy save")
	check(not saves.load_game(), "Loading must not race an ongoing respawn")
	pause_menu._save()
	check(pause_menu.status_label.text.contains("checkpoint"), "Menu must explain a defeat rejection")
	await create_timer(0.8).timeout
	saves.delete_save()
	print("Save runtime: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
