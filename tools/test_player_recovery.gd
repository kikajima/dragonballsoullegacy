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
	saves.save_path = "res://audit-recovery-save.json"
	game.get_node("GameSession").autosave_on_quest_complete = false
	root.add_child(game)
	current_scene = game
	await create_timer(0.2).timeout
	var player := get_first_node_in_group("player") as Player
	var dash := game.get_node("PlayerDashSystem") as PlayerDashSystem
	player.set_physics_process(false)
	dash.set_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	var speed := player.movement_component.move_speed
	var ki := player.ki_component.current_ki
	Input.action_press("move_right")
	player.status_effect_component.apply_status(&"stun", 60.0)
	player._process_stunned(0.0)
	dash._try_start_dash()
	check(is_equal_approx(player.ki_component.current_ki, ki), "Stun must reject dash without spending Ki")
	check(is_zero_approx(dash._dash_left), "Stun must not start dash")
	# Restore a neutral setup even when reproducing the old bug.
	dash._finish_dash()
	dash._dash_left = 0.0
	dash._cooldown_left = 0.0
	player.status_effect_component.clear_all()
	player.ki_component.restore_full()
	dash._try_start_dash()
	check(dash._dash_left > 0.0, "Healthy moving player can dash")
	check(is_equal_approx(player.ki_component.current_ki, player.ki_component.max_ki - dash.dash_ki_cost), "Valid dash spends Ki once")
	check(player.movement_component.move_speed > speed, "Valid dash increases speed")
	player.status_effect_component.apply_status(&"stun", 60.0)
	dash._process(0.01)
	check(is_zero_approx(dash._dash_left), "Stun interrupts an existing dash")
	check(is_equal_approx(player.movement_component.move_speed, speed), "Interrupted dash restores movement speed")
	Input.action_release("move_right")
	# Exercise the actual asynchronous death/fade/respawn flow.
	player.combo_tracker_component.register_hit(10)
	player._hurt_time_left = 10.0
	player.health_component.take_damage(player.health_component.max_health)
	check(player._respawning, "Lethal damage begins respawn")
	for frame in range(120):
		if not player._respawning:
			break
		await create_timer(0.01).timeout
	check(not player._respawning, "Respawn completes")
	check(player.health_component.current_health == player.health_component.max_health, "Respawn restores health")
	check(not player.status_effect_component.has_status(&"stun"), "Respawn clears pre-death stun")
	check(player.combo_tracker_component.hit_count == 0, "Respawn clears combo")
	check(is_zero_approx(player._hurt_time_left), "Respawn clears hit recovery timer")
	check(player.hurtbox.receive_hit(10, player.global_position + Vector2.LEFT) == 0, "Respawn grace prevents immediate damage")
	player.hurtbox._process(2.0)
	check(player.hurtbox.receive_hit(10, player.global_position + Vector2.LEFT) == 10, "Respawn grace expires normally")
	saves.delete_save()
	print("Player recovery: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
