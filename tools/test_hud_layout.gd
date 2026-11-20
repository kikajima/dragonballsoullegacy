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
	game.get_node("GameSession").autosave_on_quest_complete = false
	await create_timer(0.2).timeout
	var ui := game.get_node("UIContainer")
	var bars := ui.get_node("CombatHUD") as CombatHUD
	var hud := ui.get_node("SpecialStatusHUD") as SpecialStatusHUD
	var player := get_first_node_in_group("player") as Player
	var special := player.special_attack_component
	for index in special.abilities.size():
		special._selected_index = index
		special._emit_selection()
		hud._refresh()
		var label := hud.name_label
		var font := label.get_theme_font("font")
		var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		check(width <= label.size.x, "Skill name clipped: " + label.text)
		check(hud.get_node("Panel/Icon").texture != null, "Missing icon: " + label.text)
		hud._on_cooldown_changed(special.get_selected().ability_id, 0.5)
		check(hud.meter_fill.size.x <= hud.meter_back.size.x, "Cooldown exceeds track")
		check(hud.status_label.text.begins_with("RECARGA"), "Cooldown feedback")
		check(hud.get_node("Panel/Icon").modulate.r < 1.0, "Unavailable skill should dim its icon")
	special._selected_index = 0
	special._emit_selection()
	player.ability_loadout_component._cooldowns.clear()
	player.ki_component.restore_full()
	hud._on_cast_rejected("Ki insuficiente")
	check(special.start_cast(&"right", Vector2.RIGHT), "Charge starts")
	special.tick_cast(player, 0.13, true)
	hud._on_charge_changed(special.get_selected().ability_id, 0.5)
	check(hud.meter_back.visible and hud.status_label.text.contains("50%"), "Charge indicator")
	check(hud.status_label.text.contains("SEGURE O"), "Continuous attack must explain sustaining input")
	check(hud.get_node("Panel/Icon").modulate == Color.WHITE, "Successful retry clears dimmed error feedback")
	hud._on_cast_rejected("Ki insuficiente")
	check(hud.status_label.text == "Ki insuficiente", "Rejection feedback")
	for value in [0, 25, 100]:
		bars._on_health_changed(value, 100)
		bars._on_ki_changed(value, 100)
		check(bars.hp_fill.visible == (value > 0), "HP visibility at zero")
		check(bars.hp_fill.size.x == floorf(122 * value / 100.0), "HP fill width")
		check(bars.ki_fill.size.x == floorf(122 * value / 100.0), "Ki fill width")
	for pair in [["SpecialStatusHUD", "InteractionPrompt"], ["SpecialStatusHUD", "LocationBanner"], ["ResourceHUD", "QuestTracker"], ["QuestTracker", "TrainingHUD"]]:
		var first := ui.get_node(pair[0]) as Control
		var second := ui.get_node(pair[1]) as Control
		check(not first.get_global_rect().intersects(second.get_global_rect()), "HUD overlap: " + str(pair))
	check(not bars.player_panel.get_global_rect().intersects(hud.get_global_rect()), "Skill must remain below vitals")
	var feed := ui.get_node("NotificationFeed") as NotificationFeed
	for message in ["+25 XP", "Senzu Bean unavailable or not needed", "Quest complete: Master Roshi's training — practice your techniques and return to the island"]:
		feed._queue.clear()
		feed.hide()
		feed.push_message(message)
		await process_frame
		check(feed.label.text == message, "Notification must preserve the complete message")
		check(feed.size.x <= 220 and feed.size.y <= 40, "Notification must stay compact")
		check(feed.get_global_rect().end.y <= root.get_visible_rect().size.y, "Notification outside viewport")
		for other in ["QuestTracker", "SpecialStatusHUD", "InteractionPrompt", "LocationBanner"]:
			check(not feed.get_global_rect().intersects((ui.get_node(other) as Control).get_global_rect()), "Notification overlap: " + other)
	print("HUD layout: %s — all %d skills, resource limits and overlay separation" % ["PASS" if failures == 0 else "FAIL", special.abilities.size()])
	quit(failures)
