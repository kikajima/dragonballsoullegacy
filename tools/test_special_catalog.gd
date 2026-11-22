extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := load("res://scenes/bootstrap/bootstrap.tscn").instantiate() as Node2D
	var saves := game.get_node("SaveManager") as SaveManager
	saves.save_path = "res://audit-special-catalog-save.json"
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
	var loadout := player.ability_loadout_component
	var ki := special.ki_component
	var forms := special.transformation_component
	forms.set_process(false)
	var hud := game.get_node("UIContainer/SpecialStatusHUD") as SpecialStatusHUD
	var directions := {&"right": Vector2.RIGHT, &"left": Vector2.LEFT, &"up": Vector2.UP, &"down": Vector2.DOWN}
	if "--visual" in OS.get_cmdline_user_args():
		directions = {&"right": Vector2.RIGHT}
	var count := 0
	for index in special.abilities.size():
		var data := special.abilities[index]
		if "--spirit" in OS.get_cmdline_user_args() and data.ability_id != &"spirit_bomb":
			continue
		if "--namek" in OS.get_cmdline_user_args() and data.ability_id != &"super_namek":
			continue
		for facing in directions:
			player.global_position = Vector2(480, 360)
			forms.end_transformation()
			loadout._cooldowns.clear()
			ki.restore_full()
			special._selected_index = index
			special._emit_selection()
			check(special.start_cast(facing, directions[facing]), "Start failed: " + String(data.ability_id))
			if data.ability_id == &"spirit_bomb":
				check(special.get_cast_state() == &"special_spirit_charge", "Spirit Bomb must prepare with raised hands")
				check(player.get_node("Visuals/AnimatedSprite2D").sprite_frames.has_animation(StringName("special_spirit_charge_%s" % facing)), "Missing directional Spirit Bomb pose")
			if data.ability_id == &"super_namek":
				check(special.get_cast_state() != &"special_transform", "Super Namek uses Saiyan animation")
			for frame in 120:
				special.tick_cast(player, 1.0 / 60.0, frame < 50)
				if special.is_casting():
					player.animation_controller.update_visual(special.get_cast_state(), facing, 1.0 / 60.0)
				else:
					player.animation_controller.update_visual(&"idle", facing, 1.0 / 60.0)
				await physics_frame
				if frame == 55 and special._fired:
					check(not hud.status_label.text.begins_with("CARGA"), "Charge label survived firing")
				if facing == &"right" and frame in [40, 55] and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://audit-skill-%s-%d.png" % [data.ability_id, frame])
			check(not special.is_casting(), "Cast stuck: " + String(data.ability_id))
			check(hud.visible and hud.name_label.text.begins_with(data.display_name), "HUD selection mismatch")
			check(ki.current_ki < ki.max_ki, "No Ki consumed: " + String(data.ability_id))
			if data.is_transformation():
				check(forms.active_transformation == data.transformation_id, "Form failed")
			count += 1
		print("CATALOG PASS: ", data.ability_id, " (", directions.size(), " directions)")
	# Insufficient Ki must explain rejection and never enter a cast.
	special._selected_index = 0
	special._emit_selection()
	loadout._cooldowns.clear()
	ki.current_ki = 0.0
	check(not special.start_cast(&"right", Vector2.RIGHT), "Empty Ki accepted")
	check(hud.status_label.text == "KI INSUFICIENTE", "Missing rejection feedback")
	# Holding an underfunded charge must release, not leave the player stuck.
	ki.current_ki = special.get_selected().ki_cost + 0.1
	check(special.start_cast(&"right", Vector2.RIGHT), "Partial charge rejected")
	for frame in 120:
		special.tick_cast(player, 1.0 / 60.0, true)
		await physics_frame
	check(not special.is_casting(), "Ki exhaustion left beam stuck")
	# Acquired forms work after loading a save without a separate form unlock.
	special.unlock_all_for_prototype = false
	forms.load_state({"unlocked": [], "active": ""})
	loadout.load_state({"unlocked": ["super_namek"], "slots": []})
	ki.restore_full()
	loadout._cooldowns.clear()
	check(special.get_selected().ability_id == &"super_namek", "Ownership filter failed")
	check(special.start_cast(&"right", Vector2.RIGHT), "Owned form rejected")
	for frame in 60:
		special.tick_cast(player, 1.0 / 60.0, false)
		await physics_frame
	check(forms.active_transformation == &"super_namek", "Owned form blocked by old save")
	print("Special catalog: ", count, " casts; ", failures, " failures")
	saves.delete_save()
	quit(0 if failures == 0 else 1)
