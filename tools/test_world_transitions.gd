extends SceneTree

var failures := 0
var returned := [false, false]
var results := [false, false]

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func request_world(manager: WorldManager, path: String, slot: int) -> void:
	results[slot] = await manager.load_world_with_transition(path, Vector2(240, 185), true)
	returned[slot] = true

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-transition-save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.15).timeout
	var manager := game.get_node("WorldManager") as WorldManager
	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	var transition := get_first_node_in_group("screen_transition") as ScreenTransition
	transition.default_duration = 0.03
	var city := "res://scenes/world/west_city_outskirts.tscn"
	var wastes := "res://scenes/world/rocky_wastes.tscn"
	request_world(manager, city, 0)
	request_world(manager, wastes, 1)
	await create_timer(0.4).timeout
	check(returned[0] and returned[1], "Both concurrent requests must return; no abandoned fade coroutine")
	check(results[0] and not results[1], "First transition wins and concurrent request is rejected")
	check(manager.current_world_path == city, "Concurrent input must not redirect the active journey")
	check(is_zero_approx(transition.shade.modulate.a), "Transition must leave the screen clear")
	manager.load_world(city, Vector2(240, 185), true)
	# Keep this portal outside the current map to inspect its retry state.
	var portal := WorldPortal.new()
	portal.target_scene = "res://scenes/world/nonexistent_transition_test.tscn"
	portal.reset_training_environment = false
	game.add_child(portal)
	portal.interact(player)
	await create_timer(0.25).timeout
	check(not portal._transitioning, "Invalid destination must release portal for retry")
	check(manager.current_world_path == city, "Failed portal must preserve the active map")
	portal.target_scene = wastes
	portal.target_spawn = Vector2(190, 360)
	portal.interact(player)
	await create_timer(0.3).timeout
	check(manager.current_world_path == wastes, "Portal retry must load corrected destination")
	check(not portal._transitioning, "Surviving portal must clear its busy state after success")
	# Real scene-owned portals are freed by travel before fade-in completes.
	portal.queue_free()
	await process_frame
	var real_portal := WorldPortal.new()
	real_portal.target_scene = city
	real_portal.target_spawn = Vector2(240, 185)
	manager.world_container.get_child(0).add_child(real_portal)
	real_portal.interact(player)
	await create_timer(0.3).timeout
	check(not is_instance_valid(real_portal), "Outgoing portal should be freed")
	check(manager.current_world_path == city, "Scene-owned portal must finish travel")
	check(is_zero_approx(transition.shade.modulate.a), "Scene-owned portal must finish fade-in")
	# Death and travel share ScreenTransition: neither may cancel the other's tween.
	returned[0] = false
	request_world(manager, wastes, 0)
	player.health_component.take_damage(player.health_component.max_health)
	await create_timer(1.1).timeout
	check(returned[0], "Death during travel must not strand its caller")
	check(not manager.is_transitioning() and not player._respawning, "Travel/death must both complete")
	check(player.health_component.current_health > 0, "Death during travel must restore health")
	check(is_zero_approx(transition.shade.modulate.a), "Death during travel must leave screen clear")
	# Recover test setup even on the old buggy implementation.
	manager._transition_in_progress = false
	player._respawning = false
	player.health_component.restore_full()
	returned[1] = false
	player.health_component.take_damage(player.health_component.max_health)
	await process_frame
	request_world(manager, city, 1)
	await create_timer(0.9).timeout
	check(returned[1] and not results[1], "Travel during respawn must be rejected promptly")
	check(not player._respawning and player.health_component.current_health > 0, "Rejected travel must not interrupt respawn")
	saves.delete_save()
	print("World transitions: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
