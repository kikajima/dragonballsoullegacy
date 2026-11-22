extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-special-hits-save.json"
	root.add_child(game)
	current_scene = game
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	var player := get_first_node_in_group("player") as Player
	# Sword techniques (Cross Slash, Sword Blast) need the sword equipped.
	player.inventory_component.add_item(&"sword", 1)
	player.equipment_component.equip(&"sword")
	player._equip_pose_left = 0.0
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await physics_frame
	var special := player.special_attack_component
	for index in special.abilities.size():
		var data := special.abilities[index]
		if data.is_transformation():
			continue
		player.position = Vector2(420, 360)
		var target := load("res://actors/enemies/debug_goku_enemy.tscn").instantiate() as DebugGokuEnemy
		game.add_child(target)
		target.set_physics_process(false)
		target.health_component.max_health = 10000
		target.health_component.restore_full()
		var distance := 28.0
		if data.attack_type == SpecialAttackData.AttackType.ARC_GRENADE:
			distance = 210.0
		elif data.projectile_speed > 0.0 and data.attack_type in [0, 1, 2, 4]:
			distance = 80.0
		target.position = player.position + Vector2(distance, 0)
		await physics_frame
		special._selected_index = index
		special.loadout_component._cooldowns.clear()
		special.ki_component.restore_full()
		special.start_cast(&"right", Vector2.RIGHT)
		var stunned := false
		for frame in 130:
			special.tick_cast(player, 1.0 / 60.0, frame < 50)
			await physics_frame
			stunned = stunned or target.get_node("Components/StatusEffectComponent").has_status(&"stun")
		var damage := 10000 - target.health_component.current_health
		var passed: bool = stunned if data.attack_type == SpecialAttackData.AttackType.AREA_STATUS else damage > 0
		if not passed:
			failures += 1
			push_error("No hit/status: " + String(data.ability_id))
		print("HIT ", data.ability_id, ": damage=", damage, " stun=", stunned, " pass=", passed)
		target.queue_free()
		await physics_frame
	print("Special hits: ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)
