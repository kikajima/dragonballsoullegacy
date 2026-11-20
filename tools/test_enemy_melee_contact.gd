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

	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	var directions := {
		"enemy_north": [Vector2(0, 32), &"down"],
		"enemy_south": [Vector2(0, -32), &"up"],
		"enemy_west": [Vector2(32, 0), &"right"],
		"enemy_east": [Vector2(-32, 0), &"left"],
	}

	for label in directions:
		var enemy := load(
			"res://actors/enemies/debug_goku_enemy.tscn"
		).instantiate() as DebugGokuEnemy
		game.add_child(enemy)
		enemy.set_physics_process(false)
		check(
			enemy.vertical_attack_range >= 32.0,
			"Enemy attack range must reach vertical body contact"
		)
		enemy.position = Vector2(420, 360)
		player.position = enemy.position + directions[label][0]
		player.health_component.restore_full()
		await physics_frame

		enemy.melee_combat_component.start_attack(
			directions[label][1],
			&"punch"
		)
		for _frame in 24:
			enemy.melee_combat_component.tick_attack(1.0 / 60.0)
			await physics_frame

		check(
			player.health_component.current_health < player.health_component.max_health,
			"Enemy melee contact failed from " + label
		)
		print("ENEMY MELEE ", label, ": damage=", player.health_component.max_health - player.health_component.current_health)
		enemy.queue_free()
		await create_timer(0.5).timeout

	var ai_cases := {
		"south": Vector2(420, 420),
		"west": Vector2(360, 360),
		"east": Vector2(480, 360),
	}
	for label in ai_cases:
		var ai_enemy := load(
			"res://actors/enemies/debug_goku_enemy.tscn"
		).instantiate() as DebugGokuEnemy
		game.add_child(ai_enemy)
		ai_enemy.position = ai_cases[label]
		ai_enemy.ai_component.profile.ranged_attack_chance = 0.0
		ai_enemy.attack_cooldown = 0.2
		player.position = Vector2(420, 360)
		player.health_component.restore_full()
		for _frame in 120:
			await physics_frame
		check(
			player.health_component.current_health < player.health_component.max_health,
			"Enemy AI must attack when approaching from the " + label
		)
		ai_enemy.queue_free()
		await create_timer(0.5).timeout

	print("Enemy melee contact: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
