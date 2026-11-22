extends SceneTree

# The test arena is Kame Island, wherever it sits in the open world.
const ISLAND := Vector2(5504, 2752)

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout

	var player := get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	_check(
		player.get_node_or_null("GbaContactShadow") == null,
		"Player must not have a duplicate contact shadow"
	)
	_check(player.collision_mask == 5, "Player must collide with enemy bodies")
	var movement_target := load(
		"res://actors/enemies/debug_goku_enemy.tscn"
	).instantiate() as DebugGokuEnemy
	game.add_child(movement_target)
	movement_target.set_physics_process(false)
	movement_target.position = ISLAND + Vector2(420, 360)
	player.position = ISLAND + Vector2(420, 300)
	player.velocity = Vector2.DOWN * 90.0
	for _frame in 30:
		player.move_and_slide()
		await physics_frame
	_check(
		absf(player.position.y - movement_target.position.y) <= 34.0,
		"Player must stop at enemy body contact"
	)
	player.facing_component.update_from_direction(Vector2.DOWN)
	player.melee_combat_component.start_attack(&"down", &"punch")
	for _frame in 24:
		player.melee_combat_component.tick_attack(1.0 / 60.0)
		await physics_frame
	_check(
		movement_target.health_component.current_health < movement_target.health_component.max_health,
		"Melee must reach an enemy at body contact"
	)
	movement_target.queue_free()
	player.velocity = Vector2.ZERO
	await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame

	var directions := {
		"north": [Vector2(0, -32), &"down"],
		"south": [Vector2(0, 4), &"up"],
		"west": [Vector2(-16, 0), &"right"],
		"east": [Vector2(16, 0), &"left"],
	}

	for label in directions:
		var target := load(
			"res://actors/enemies/debug_goku_enemy.tscn"
		).instantiate() as DebugGokuEnemy
		game.add_child(target)
		target.set_physics_process(false)
		_check(target.collision_mask == 7, "Enemy body must collide with player, world and other enemies")
		target.health_component.max_health = 10000
		target.health_component.restore_full()
		target.position = ISLAND + Vector2(420, 360)
		player.position = target.position + directions[label][0]
		player.melee_combat_component.cancel_attack()
		player.facing_component.update_from_direction(
			_directions_to_vector(directions[label][1])
		)
		await physics_frame

		player.melee_combat_component.start_attack(
			directions[label][1],
			&"punch"
		)
		for _frame in 24:
			player.melee_combat_component.tick_attack(1.0 / 60.0)
			await physics_frame

		var damage := 10000 - target.health_component.current_health
		_check(damage > 0, "Melee contact failed from " + label)
		print("MELEE ", label, ": damage=", damage)
		target.queue_free()
		await physics_frame

	print("Melee contact: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func _directions_to_vector(direction: StringName) -> Vector2:
	match direction:
		&"up":
			return Vector2.UP
		&"down":
			return Vector2.DOWN
		&"left":
			return Vector2.LEFT
		&"right":
			return Vector2.RIGHT
	return Vector2.DOWN
